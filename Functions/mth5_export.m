function out = mth5_export(filename, rootPath)
%MTH5_EXPORT  Export an MTH5/HDF5 file into a MATLAB struct (FULL READ).
% -------------------------------------------------------------------------
% This exporter performs a *full read* of the HDF5 hierarchy starting at
% `rootPath`, including:
%   - group and dataset structure (recursive)
%   - attribute values (optional)
%   - dataset values via h5read() (optional, can be huge)
%
% USAGE
%   out = mth5_export(filename)
%   out = mth5_export(filename, rootPath)
%   out = mth5_export()                 % opens file picker
%
% OUTPUT
%   out.file        : filename
%   out.rootPath    : root path considered
%   out.exportedAt  : export timestamp (datestr)
%   out.tree        : exported tree with uniform node schema
%
% IMPORTANT
%   FULL READ of datasets can exceed memory for large MTH5 files.
%   This function intentionally avoids string() for compatibility.
% -------------------------------------------------------------------------
%   Author: César Castro
%   Last update: 06-Jan-2026
% -------------------------------------------------------------------------

    % =====================================================================
    % 0) Inputs / file picker
    % =====================================================================
    if nargin < 1 || isempty(filename)

        [f, p] = uigetfile( ...
            {'*.h5;*.hdf5;*.mth5','HDF5/MTH5 files'; '*.*','All files'}, ...
            'Select MTH5/HDF5 file' ...
        );

        if isequal(f, 0)
            out = [];
            return;
        end

        filename = fullfile(p, f);
    end

    if nargin < 2 || isempty(rootPath)
        rootPath = '/';
    end

    % =====================================================================
    % 1) Options
    % =====================================================================
    opts.readDatasetData      = true;    % FULL dataset read (h5read)
    opts.readAttributeValues  = true;    % read attribute values (h5readatt)
    opts.failOnReadError      = false;   % throw if any read fails
    opts.maxDatasetElements   = Inf;     % safety limit (e.g., 5e7)

    % =====================================================================
    % 2) Export header
    % =====================================================================
    out            = struct();
    out.file       = filename;
    out.rootPath   = rootPath;
    out.exportedAt = datestr(now);

    % =====================================================================
    % 3) Recursive export
    % =====================================================================
    out.tree = digest_group(filename, rootPath, tail_name(rootPath), opts);

end

% =====================================================================
% CORE DIGESTERS
% =====================================================================

function node = digest_group(file, groupPath, groupName, opts)
%DIGEST_GROUP  Export an HDF5 group recursively.

    info = h5info(file, groupPath);

    node = new_node('group', groupName, groupPath);

    % ---------------------------------------------------------------------
    % 1) Attributes
    % ---------------------------------------------------------------------
    node.attrs = read_attrs(file, groupPath, info.Attributes, opts);

    % ---------------------------------------------------------------------
    % 2) Children: groups first, then datasets
    % ---------------------------------------------------------------------
    kids = empty_nodes();

    for k = 1:numel(info.Groups)
        g     = info.Groups(k);
        child = digest_group(file, g.Name, tail_name(g.Name), opts);
        kids(end+1) = child; %#ok<AGROW>
    end

    for k = 1:numel(info.Datasets)
        d     = info.Datasets(k);
        dPath = join_h5_path(groupPath, d.Name);

        child = digest_dataset(file, dPath, d.Name, opts);
        kids(end+1) = child; %#ok<AGROW>
    end

    node.children = kids;

end

function node = digest_dataset(file, dsetPath, dsetName, opts)
%DIGEST_DATASET  Export a dataset (metadata + optional values).

    info = h5info(file, dsetPath);

    node = new_node('dataset', dsetName, dsetPath);

    % ---------------------------------------------------------------------
    % 1) Dataset metadata
    % ---------------------------------------------------------------------
    try, node.meta.size  = info.Dataspace.Size;   catch, node.meta.size  = [];  end
    try, node.meta.class = info.Datatype.Class;   catch, node.meta.class = '';  end
    try, node.meta.ndims = numel(node.meta.size); catch, node.meta.ndims = [];  end

    % ---------------------------------------------------------------------
    % 2) Dataset attributes
    % ---------------------------------------------------------------------
    node.attrs = read_attrs(file, dsetPath, info.Attributes, opts);

    % ---------------------------------------------------------------------
    % 3) Dataset values (optional full read)
    % ---------------------------------------------------------------------
    node.read_ok    = false;
    node.read_error = '';
    node.data       = [];

    if ~opts.readDatasetData
        return;
    end

    % --- Optional safety limit on total elements
    try
        if isnumeric(node.meta.size) && ~isempty(node.meta.size)

            nEl = prod(double(node.meta.size));

            if isfinite(opts.maxDatasetElements) && nEl > opts.maxDatasetElements
                node.read_ok    = false;
                node.read_error = sprintf('Skipped: too large (%g elements > limit).', nEl);
                return;
            end
        end
    catch
    end

    % --- Read full dataset
    try
        node.data    = h5read(file, dsetPath);
        node.read_ok = true;

    catch ME
        node.read_ok    = false;
        node.read_error = ME.message;

        if opts.failOnReadError
            rethrow(ME);
        end
    end

end

% =====================================================================
% ATTRIBUTES
% =====================================================================

function attrs = read_attrs(file, objPath, attrList, opts)
%READ_ATTRS  Read attribute values into a uniform schema.

    attrs = struct('name', {}, 'value', {}, 'read_ok', {}, 'read_error', {});

    if isempty(attrList)
        return;
    end

    for k = 1:numel(attrList)

        aName = attrList(k).Name;

        a            = struct();
        a.name       = aName;
        a.value      = [];
        a.read_ok    = false;
        a.read_error = '';

        if opts.readAttributeValues
            try
                a.value   = h5readatt(file, objPath, aName);
                a.read_ok = true;

            catch ME
                a.read_ok    = false;
                a.read_error = ME.message;

                if opts.failOnReadError
                    rethrow(ME);
                end
            end
        end

        attrs(end+1) = a; %#ok<AGROW>
    end

end

% =====================================================================
% NODE SCHEMA
% =====================================================================

function node = new_node(type, name, path)
%NEW_NODE  Create a node with a uniform schema (no recursion here).

    node = node_schema();

    node.type = type;   % 'group'|'dataset'
    node.name = name;
    node.path = path;

    % children must be an EMPTY ARRAY of node_schema
    node.children = empty_nodes();

end

function node = node_schema()
%NODE_SCHEMA  Base node schema (no children initialization here).

    node = struct();

    node.type = '';          % 'group'|'dataset'
    node.name = '';
    node.path = '';

    node.attrs = struct('name', {}, 'value', {}, 'read_ok', {}, 'read_error', {});

    node.children = [];      % set by new_node()

    node.meta = struct('size', [], 'class', '', 'ndims', []);

    node.data       = [];
    node.read_ok    = [];
    node.read_error = '';

end

function arr = empty_nodes()
%EMPTY_NODES  Empty struct array with correct schema.

    tmp = node_schema();
    arr = tmp([]);  % 0x0 struct with correct fields

end

% =====================================================================
% PATH UTILITIES
% =====================================================================

function out = tail_name(pathStr)
%TAIL_NAME  Return last token of an HDF5 path.

    pathStr = safe_char(pathStr);

    if isempty(pathStr) || strcmp(pathStr, '/')
        out = '/';
        return;
    end

    if pathStr(end) == '/'
        pathStr = pathStr(1:end-1);
    end

    idx = find(pathStr == '/', 1, 'last');

    if isempty(idx)
        out = pathStr;
    else
        out = pathStr(idx+1:end);
    end

end

function p = join_h5_path(groupPath, name)
%JOIN_H5_PATH  Join group path + object name into a valid HDF5 path.

    groupPath = safe_char(groupPath);
    name      = safe_char(name);

    if isempty(groupPath) || strcmp(groupPath, '/')
        p = ['/' name];
        return;
    end

    if groupPath(end) == '/'
        p = [groupPath name];
    else
        p = [groupPath '/' name];
    end

end

function out = safe_char(x)
%SAFE_CHAR  Convert to char safely without using string().

    if isempty(x)
        out = '';
        return;
    end

    if ischar(x)
        out = x;

    elseif iscell(x) && numel(x) == 1 && ischar(x{1})
        out = x{1};

    else
        try
            out = char(x);
        catch
            try
                out = strtrim(evalc('disp(x)'));
            catch
                out = '<unprintable>';
            end
        end
    end

end
