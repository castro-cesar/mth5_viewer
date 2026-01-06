function mth5_on_select(src, evt, textArea, ax)
%MTH5_ON_SELECT  UITREE selection callback (info panel + quick-look plot).
% -------------------------------------------------------------------------
% This callback is intended to be assigned to a UITREE:
%   app.Tree.SelectionChangedFcn = @(src,evt) mth5_on_select(src, evt, app.TextArea, app.UIAxes);
%
% Behavior:
%   - GROUP node      : show h5info() summary (counts of groups/datasets/attrs)
%   - DATASET node    : show dataset size/type and (if 1-D) plot with stride read
%   - ATTRIBUTE node  : show value preview and best-effort HDF5 reference resolution
%
% INPUTS:
%   src       : uitree handle (expects src.UserData.file to exist)
%   evt       : SelectionChanged event (expects evt.SelectedNodes)
%   textArea  : uitextarea handle (or compatible UI component)
%   ax        : uiaxes handle (optional; used for quick-look plotting)
% -------------------------------------------------------------------------
%   Author: César Castro
%   Last update: 06-Jan-2026
% -------------------------------------------------------------------------

    % =====================================================================
    % 0) Validate selection + file context
    % =====================================================================
    if isempty(evt.SelectedNodes)
        return;
    end

    node = evt.SelectedNodes(1);
    nd   = node.NodeData;

    if isempty(nd) || ~isfield(nd, 'type')
        mth5_set_text(textArea, {'No NodeData.'});
        return;
    end

    if ~isfield(src.UserData, 'file') || isempty(src.UserData.file)
        mth5_set_text(textArea, { ...
            'Tree.UserData.file missing.', ...
            'Ensure mth5_populate_uitree() set it.' ...
        });
        return;
    end

    file = src.UserData.file;
    t    = lower(mth5_safe_char(nd.type));

    % =====================================================================
    % 1) GROUP node: summarize children + attributes
    % =====================================================================
    if strcmpi(t, 'group')

        p    = mth5_safe_char(nd.path);
        info = h5info(file, p);

        lines = { ...
            'TYPE: group', ...
            ['PATH: ' p], ...
            ['GROUPS  : ' num2str(numel(info.Groups))], ...
            ['DATASETS: ' num2str(numel(info.Datasets))], ...
            ['ATTRS   : ' num2str(numel(info.Attributes))] ...
        };

        mth5_set_text(textArea, lines);
        return;
    end

    % =====================================================================
    % 2) ATTRIBUTE node: show value + try resolve references
    % =====================================================================
    if strcmpi(t, 'attribute')

        owner = '';
        name  = '';

        if isfield(nd, 'owner_path'), owner = mth5_safe_char(nd.owner_path); end
        if isfield(nd, 'name'),       name  = mth5_safe_char(nd.name);       end

        valStr = '<no value>';
        if isfield(nd, 'value')
            valStr = mth5_preview_value(nd.value, 500);
        end

        lines = { ...
            'TYPE: attribute', ...
            ['OWNER: ' owner], ...
            ['NAME : ' name], ...
            ['VALUE: ' valStr] ...
        };

        % Resolve HDF5 object reference (best-effort)
        if isfield(nd, 'value') && is_hdf5_reference(nd.value)

            [ok, refPath, refInfo] = try_resolve_hdf5_reference(file, nd.value);

            if ok
                lines = [lines; {['REF -> ' refPath]}]; %#ok<AGROW>
                if ~isempty(refInfo)
                    lines = [lines; refInfo(:)]; %#ok<AGROW>
                end
            else
                lines = [lines; {'REF -> (could not resolve in this MATLAB version)'}]; %#ok<AGROW>
            end
        end

        mth5_set_text(textArea, lines);
        return;
    end

    % =====================================================================
    % 3) DATASET node: show metadata + quick-look plot (stride read)
    % =====================================================================
    if strcmpi(t, 'dataset')

        p    = mth5_safe_char(nd.path);
        info = h5info(file, p);

        % --- Size string
        szStr = '[]';
        try
            szStr = ['[' mth5_join_num(info.Dataspace.Size, 'x') ']'];
        catch
        end

        % --- Datatype class
        dtype = '<unknown>';
        try
            dtype = info.Datatype.Class;
        catch
        end

        lines = { ...
            'TYPE: dataset', ...
            ['PATH : ' p], ...
            ['SIZE : ' szStr], ...
            ['DTYPE: ' dtype], ...
            ['ATTRS: ' num2str(numel(info.Attributes))] ...
        };
        mth5_set_text(textArea, lines);

        % --- Plot (if axes provided)
        if nargin >= 4 && ~isempty(ax) && isvalid(ax)

            try
                y = mth5_h5read_for_plot(file, p, 200000);

                cla(ax);
                plot(ax, y);
                grid(ax, 'on');
                title(ax, p, 'Interpreter', 'none');
                set(ax, 'Box', 'on');

                ax.Visible = 'on';

            catch
                cla(ax);
                ax.Visible = 'off';
            end
        end

        return;
    end

    % =====================================================================
    % 4) Unknown node type
    % =====================================================================
    if nargin >= 4 && ~isempty(ax) && isvalid(ax)
        ax.Visible = 'off';
    end

    mth5_set_text(textArea, {['Unknown node type: ' mth5_safe_char(nd.type)]});
end

% =====================================================================
% LOCAL HELPERS
% =====================================================================

function out = mth5_safe_char(x)
%MTH5_SAFE_CHAR  Convert value to char safely (without using string()).

    if isempty(x)
        out = '';
    elseif ischar(x)
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

function mth5_set_text(textArea, lines)
%MTH5_SET_TEXT  Set UI text robustly without relying on string().

    if isempty(textArea) || ~isvalid(textArea)
        return;
    end

    if nargin < 2 || isempty(lines)
        lines = {''};
    end

    % Normalize input to a cell array of char
    if ischar(lines)
        lines = {lines};
    elseif ~iscell(lines)
        try
            lines = {evalc('disp(lines)')};
        catch
            lines = {'<unprintable>'};
        end
    end

    for i = 1:numel(lines)
        if ~ischar(lines{i})
            try
                lines{i} = char(lines{i});
            catch
                try
                    lines{i} = strtrim(evalc('disp(lines{i})'));
                catch
                    lines{i} = '<unprintable>';
                end
            end
        end
    end

    % Prefer uitextarea Value = cellstr
    try
        textArea.Value = lines(:);
        return;
    catch
    end

    % Fallback: join into a single newline-delimited string
    one = lines{1};
    for i = 2:numel(lines)
        one = [one sprintf('\n') lines{i}]; %#ok<AGROW>
    end

    try
        textArea.Value = one;
    catch
        if isprop(textArea, 'Text')
            textArea.Text = one;
        end
    end
end

function out = mth5_preview_value(v, maxChars)
%MTH5_PREVIEW_VALUE  Safe, compact preview of an attribute value.

    if nargin < 2 || isempty(maxChars)
        maxChars = 200;
    end

    try
        if ischar(v)
            out = v;

        elseif isnumeric(v) || islogical(v)
            if isempty(v)
                out = '';
            elseif isscalar(v)
                out = num2str(v);
            else
                out = sprintf('%s [%s] ...', class(v), mth5_join_num(size(v), 'x'));
            end

        elseif iscell(v)
            if isempty(v)
                out = 'cell{}';
            elseif numel(v) == 1
                out = ['cell{1}: ' mth5_preview_value(v{1}, maxChars)];
            else
                out = sprintf('cell{%d}', numel(v));
            end

        elseif isstruct(v)
            f = fieldnames(v);
            out = ['struct fields: ' strjoin(f(:).', ', ')];

        else
            out = ['<' class(v) '>'];
        end
    catch
        out = '<unprintable>';
    end

    if numel(out) > maxChars
        out = [out(1:maxChars) '...'];
    end
end

function s = mth5_join_num(v, sep)
%MTH5_JOIN_NUM  Join numeric vector into 'a{sep}b{sep}c' string.

    c = cell(1, numel(v));
    for i = 1:numel(v)
        c{i} = num2str(v(i));
    end

    s = c{1};
    for i = 2:numel(c)
        s = [s sep c{i}]; %#ok<AGROW>
    end
end

function y = mth5_h5read_for_plot(file, dsetPath, maxPoints)
%MTH5_H5READ_FOR_PLOT  Read dataset for plotting using stride/downsampling.
% - 1D datasets: read <= maxPoints using stride
% - ND datasets: read a small block (up to 50 per dimension), then vectorize

    info = h5info(file, dsetPath);
    sz   = info.Dataspace.Size;

    if isempty(sz)
        y = [];
        return;
    end

    % --- 1D case
    if numel(sz) == 1

        n = double(sz(1));

        if n <= maxPoints
            y = h5read(file, dsetPath);
        else
            stride = max(1, floor(n / maxPoints));
            start  = 1;
            count  = floor((n - start) / stride) + 1;
            y      = h5read(file, dsetPath, start, count, stride);
        end

        return;
    end

    % --- ND case: read small block
    start = ones(1, numel(sz));
    count = min(sz, repmat(50, 1, numel(sz)));

    y = h5read(file, dsetPath, start, count);
    y = y(:);
end

function tf = is_hdf5_reference(v)
%IS_HDF5_REFERENCE  Heuristic check for HDF5 reference-like attribute values.

    tf = false;

    try
        c = class(v);

        if ~isempty(strfind(lower(c), 'hdf5')) %#ok<STREMP>
            s  = lower(strtrim(evalc('disp(v)')));
            tf = ~isempty(strfind(s, 'reference')); %#ok<STREMP>
        end

    catch
        tf = false;
    end
end

function [ok, refPath, refInfo] = try_resolve_hdf5_reference(file, ref)
%TRY_RESOLVE_HDF5_REFERENCE  Best-effort resolver for HDF5 object references.
% Returns ok=false if API/signature is not supported in this MATLAB version.

    ok      = false;
    refPath = '';
    refInfo = {};

    try
        fid = H5F.open(file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
        cF  = onCleanup(@() H5F.close(fid)); %#ok<NASGU>

        % Dereference (signature differs across MATLAB releases)
        obj_id = [];
        try
            obj_id = H5R.dereference(fid, 'H5R_OBJECT', ref);
        catch
            obj_id = H5R.dereference2(fid, 'H5P_DEFAULT', 'H5R_OBJECT', ref);
        end

        % Object name/path (if available)
        try
            refPath = H5I.get_name(obj_id);
        catch
            refPath = '<resolved object (name unavailable)>';
        end

        % Basic metadata for referenced object (if it looks like a path)
        if ischar(refPath) && ~isempty(refPath) && refPath(1) == '/'
            info = h5info(file, refPath);

            refInfo = { ...
                ['REF TYPE: ' info.Type], ...
                ['REF NAME: ' info.Name] ...
            };

            try
                if isfield(info, 'Dataspace') && isfield(info.Dataspace, 'Size')
                    refInfo{end+1} = ['REF SIZE: [' mth5_join_num(info.Dataspace.Size, 'x') ']'];
                end
            catch
            end
        end

        ok = true;

        try, H5O.close(obj_id); catch, end

    catch
        ok      = false;
        refPath = '';
        refInfo = {};
    end
end
