function tree = mth5_load(file)
%MTH5_LOAD  Digest an MTH5/HDF5 file into a lightweight tree struct.
% -------------------------------------------------------------------------
% This function reads the *structure* of an MTH5 (HDF5) file using h5info(),
% and builds a lightweight MATLAB struct tree suitable for UI browsing.
%
% It does NOT read dataset values. Only:
%   - groups
%   - dataset metadata (size, datatype class)
%   - attributes (optional values via h5readatt)
%
% OUTPUT TREE NODE SCHEMA
%   node.type      : "group" | "dataset"
%   node.name      : tail name of the object
%   node.path      : full HDF5 path
%   node.attrs     : struct array with fields:
%                      - name
%                      - value
%                      - path   (objPath + "@" + attrName)
%   node.children  : struct array of child nodes (groups/datasets)
%   node.meta      : struct with dataset metadata (datasets only)
%
% ROOT EXTRA FIELD
%   tree.file      : full filename (stored for later h5read operations)
%
% USAGE
%   tree = mth5_load("my_file.h5");
%
% Developed for MATLAB R2024b.
% -------------------------------------------------------------------------
%   Author: César Castro
%   Last update: 06-Jan-2026
% -------------------------------------------------------------------------

    % =====================================================================
    % 0) Input validation
    % =====================================================================
    arguments
        file (1,1) string
    end

    if ~isfile(file)
        error("File not found: %s", file);
    end

    % =====================================================================
    % 1) Options
    % =====================================================================
    opts.readAttributes = true;

    % =====================================================================
    % 2) Digest full hierarchy (structure-only)
    % =====================================================================
    tree      = digest_group(file, "/", "/", opts);
    tree.file = file;  % keep file path available for UI callbacks (h5read)

end

% =====================================================================
% CORE DIGESTERS
% =====================================================================

function node = digest_group(file, groupPath, groupName, opts)
%DIGEST_GROUP  Recursively digest an HDF5 group into a node struct.

    info = h5info(file, groupPath);

    % --- Base node
    node       = empty_node();
    node.type  = "group";
    node.name  = string(groupName);
    node.path  = string(groupPath);
    node.meta  = struct();
    node.attrs = read_attrs(file, groupPath, info.Attributes, opts);

    % =====================================================================
    % 1) Child groups
    % =====================================================================
    for k = 1:numel(info.Groups)
        g     = info.Groups(k);
        gName = tail_name(g.Name);

        child = digest_group(file, g.Name, gName, opts);
        node.children(end+1) = child; %#ok<AGROW>
    end

    % =====================================================================
    % 2) Datasets inside this group
    % =====================================================================
    for k = 1:numel(info.Datasets)
        d = info.Datasets(k);

        dPath = string(groupPath);
        if ~endsWith(dPath, "/")
            dPath = dPath + "/";
        end
        dPath = dPath + string(d.Name);

        child = digest_dataset(file, dPath, d.Name, opts);
        node.children(end+1) = child; %#ok<AGROW>
    end

    % =====================================================================
    % 3) Sort children: groups first, then datasets (alphabetical)
    % =====================================================================
    if ~isempty(node.children)

        types = string({node.children.type});
        names = lower(string({node.children.name}));

        isGroup = (types == "group");

        % sortrows uses columns: first groups (isGroup true), then by name
        [~, ord] = sortrows([~isGroup(:), names(:)], [1 2]);
        node.children = node.children(ord);
    end

end

function node = digest_dataset(file, dsetPath, dsetName, opts)
%DIGEST_DATASET  Digest an HDF5 dataset into a node struct (metadata only).

    info = h5info(file, dsetPath);

    % --- Base node
    node       = empty_node();
    node.type  = "dataset";
    node.name  = string(dsetName);
    node.path  = string(dsetPath);
    node.attrs = read_attrs(file, dsetPath, info.Attributes, opts);

    % --- Dataset metadata
    meta = struct();
    meta.size       = [];
    meta.class      = "";
    meta.isCompound = false;

    try
        meta.size = info.Dataspace.Size;
    catch
    end

    try
        if isfield(info, "Datatype") && isfield(info.Datatype, "Class")
            meta.class = string(info.Datatype.Class);
        end
        if meta.class == "H5T_COMPOUND"
            meta.isCompound = true;
        end
    catch
    end

    node.meta = meta;

end

% =====================================================================
% ATTRIBUTES
% =====================================================================

function attrs = read_attrs(file, objPath, attrList, opts)
%READ_ATTRS  Read HDF5 attributes for the current object (best-effort).

    attrs = struct('name', {}, 'value', {}, 'path', {});

    if isempty(attrList)
        return;
    end

    for k = 1:numel(attrList)

        aName = string(attrList(k).Name);

        if opts.readAttributes
            try
                aVal = h5readatt(file, objPath, aName);
            catch
                aVal = "<unreadable>";
            end
        else
            aVal = "<skipped>";
        end

        attrs(end+1).name  = aName; %#ok<AGROW>
        attrs(end).value   = aVal;
        attrs(end).path    = string(objPath) + "@" + aName;
    end

end

% =====================================================================     
% NODE SCHEMA
% =====================================================================

function node = empty_node()
%EMPTY_NODE  Create an empty node with a consistent schema.

    node = struct( ...
        'type',     "", ...
        'name',     "", ...
        'path',     "", ...
        'attrs',    struct('name',{}, 'value',{}, 'path',{}), ...
        'children', struct('type',{}, 'name',{}, 'path',{}, 'attrs',{}, 'children',{}, 'meta',{}), ...
        'meta',     struct() ...
    );

end

% =====================================================================
% UTILITIES
% =====================================================================

function t = tail_name(h5path)
%TAIL_NAME  Return final component of an HDF5 path.

    parts = split(string(h5path), "/");
    parts(parts == "") = [];

    if isempty(parts)
        t = "/";
    else
        t = parts(end);
    end

end
