function hTree = mth5_populate_uitree(tree, parent)
%MTH5_POPULATE_UITREE  Create or populate a UITREE from a digested MTH5 tree.
% -------------------------------------------------------------------------
% This function converts a *digested* MTH5/HDF5 tree struct (from mth5_load)
% into a MATLAB UITREE suitable for browsing groups, datasets, and attributes.
%
% This function does NOT read dataset values. It uses only:
%   - structure and metadata already stored in `tree`
%   - attribute values already stored in `tree.attrs`
%
% USAGE
%   hTree = mth5_populate_uitree(tree)           % creates new figure + uitree
%   hTree = mth5_populate_uitree(tree, [])       % same as above
%   hTree = mth5_populate_uitree(tree, app.Tree) % clears + repopulates existing UITREE
%   hTree = mth5_populate_uitree(tree, parentUI) % creates a UITREE inside parent container
%
% NOTES
%   - If `tree.file` exists, it is stored in hTree.UserData.file to support
%     later callbacks (e.g., mth5_on_select uses it for h5info/h5read).
%   - Uses char/strcmp compatibility helpers (no reliance on string()).
% -------------------------------------------------------------------------
%   Author: César Castro
%   Last update: 06-Jan-2026
% -------------------------------------------------------------------------

    % =====================================================================
    % 0) Inputs
    % =====================================================================
    if nargin < 2
        parent = [];
    end

    % =====================================================================
    % 1) Create or reuse a UITREE target
    % =====================================================================
    if isempty(parent)

        fig   = uifigure('Name', 'MTH5 Browser');
        gl    = uigridlayout(fig, [1 1]);
        hTree = uitree(gl);

    else
        if is_tree_ui(parent)
            hTree = parent;
            clear_tree_nodes(hTree);
        else
            % parent must be a UI container (uifigure/uipanel/uigridlayout/...)
            hTree = uitree(parent);
        end
    end

    % =====================================================================
    % 2) Store file path for downstream callbacks
    % =====================================================================
    if isfield(tree, 'file') && ~isempty(tree.file)
        hTree.UserData = struct('file', tree.file);
    else
        hTree.UserData = struct();
    end

    % =====================================================================
    % 3) Create root node
    % =====================================================================
    rootNode          = uitreenode(hTree, 'Text', '/');
    rootNode.Icon     = get_icon('group');
    rootNode.NodeData = struct('type', 'group', 'path', '/');

    % =====================================================================
    % 4) Populate recursively
    % =====================================================================
    add_children(rootNode, tree);

    expand(rootNode);

end

% =====================================================================
% LOCAL HELPERS
% =====================================================================

function tf = is_tree_ui(h)
%IS_TREE_UI  Robust detection for a UITREE handle across MATLAB versions.

    tf = false;

    if isempty(h) || ~isvalid(h)
        return;
    end

    try
        tf = isprop(h, 'Children') && isprop(h, 'SelectionChangedFcn');
    catch
        tf = false;
    end

end

function clear_tree_nodes(hTree)
%CLEAR_TREE_NODES  Remove all nodes from an existing UITREE.

    try
        delete(hTree.Children);
    catch
        ch = hTree.Children;
        for k = 1:numel(ch)
            delete(ch(k));
        end
    end

end

function add_children(uiParentNode, node)
%ADD_CHILDREN  Recursively add attribute + child nodes under uiParentNode.

    % =====================================================================
    % 1) Attributes (sorted by name)
    % =====================================================================
    if isfield(node, 'attrs') && ~isempty(node.attrs)

        keys = cell(1, numel(node.attrs));
        for k = 1:numel(node.attrs)
            keys{k} = lower(safe_char(node.attrs(k).name));
        end

        [~, idx]    = sort(keys);
        attrsSorted = node.attrs(idx);

        for k = 1:numel(attrsSorted)

            a   = attrsSorted(k);
            txt = attribute_label(a.name, a.value);

            n      = uitreenode(uiParentNode, 'Text', txt);
            n.Icon = get_icon('attribute');

            n.NodeData = struct( ...
                'type',       'attribute', ...
                'owner_path', safe_char(node.path), ...
                'name',       safe_char(a.name), ...
                'value',      a.value ...
            );
        end
    end

    % =====================================================================
    % 2) Children (groups + datasets)
    % =====================================================================
    if ~isfield(node, 'children') || isempty(node.children)
        return;
    end

    ch = node.children;

    % ---------------------------------------------------------------------
    % Sort children by what the user sees (by name)
    % ---------------------------------------------------------------------
    keys = cell(1, numel(ch));

    for k = 1:numel(ch)

        c = ch(k);

        t = '';
        if isfield(c, 'type')
            t = safe_char(c.type);
        end

        if strcmpi(t, 'group')
            keys{k} = lower(safe_char(c.name));

        elseif strcmpi(t, 'dataset')
            % Option A: sort by dataset name only (recommended)
            keys{k} = lower(safe_char(c.name));

            % Option B: sort by full label (name + size + class)
            % keys{k} = lower(dataset_label(c));

        else
            keys{k} = '';
        end
    end

    [~, idx] = sort(keys);
    ch       = ch(idx);

    % ---------------------------------------------------------------------
    % Create UI nodes in sorted order
    % ---------------------------------------------------------------------
    for k = 1:numel(ch)

        c = ch(k);

        if ~isfield(c, 'type')
            continue;
        end

        t = safe_char(c.type);

        % --- Group node
        if strcmpi(t, 'group')

            n          = uitreenode(uiParentNode, 'Text', safe_char(c.name));
            n.Icon     = get_icon('group');
            n.NodeData = struct('type', 'group', 'path', safe_char(c.path));

            add_children(n, c);
        end

        % --- Dataset node
        if strcmpi(t, 'dataset')

            n      = uitreenode(uiParentNode, 'Text', dataset_label(c));
            n.Icon = get_icon('dataset');

            n.NodeData = struct( ...
                'type', 'dataset', ...
                'path', safe_char(c.path), ...
                'name', safe_char(c.name), ...
                'meta', c.meta ...
            );

            add_children(n, c);
        end
    end

end

function p = get_icon(kind)
%GET_ICON  Resolve an icon filename using which(). Returns '' if not found.

    switch lower(kind)
        case 'group'
            candidates = {'group.png', 'folder.png'};
        case 'dataset'
            % Prefer dataset.png if you use that name, then fall back:
            candidates = {'dataset.png', 'database.png', 'waveform.png'};
        case 'attribute'
            candidates = {'attribute.png', 'tag.png', 'info.png'};
        otherwise
            candidates = {};
    end

    p = '';

    for i = 1:numel(candidates)
        w = which(candidates{i});
        if ~isempty(w)
            p = w;
            return;
        end
    end

end

function txt = dataset_label(d)
%DATASET_LABEL  Build the dataset label shown in the UITREE.

    name = safe_char(d.name);

    % --- Size
    szStr = '';
    try
        if isfield(d, 'meta') && isfield(d.meta, 'size') && ~isempty(d.meta.size) && isnumeric(d.meta.size)
            szStr = [' [' join_num(d.meta.size, 'x') ']'];
        end
    catch
        szStr = '';
    end

    % --- Datatype class
    clsStr = '';
    try
        if isfield(d, 'meta') && isfield(d.meta, 'class') && ~isempty(d.meta.class)
            clsStr = [' <' safe_char(d.meta.class) '>'];
        end
    catch
        clsStr = '';
    end

    txt = [name szStr clsStr];

end

function txt = attribute_label(name, value) %#ok<INUSD>
%ATTRIBUTE_LABEL  Build attribute label shown in the UITREE.
% Currently shows only the attribute name (not value) to keep the tree clean.

    % Example alternative (with value preview):
    % txt = ['@' safe_char(name) ' = ' value_preview_char(value, 120)];

    txt = safe_char(name);

end

function out = safe_char(x)
%SAFE_CHAR  Convert value to char safely without using string().

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
                out = evalc('disp(x)');
                out = strtrim(out);
            catch
                out = '<unprintable>';
            end
        end
    end

end

function s = join_num(v, sep)
%JOIN_NUM  Join numeric vector into 'a{sep}b{sep}c' string.

    c = cell(1, numel(v));
    for i = 1:numel(v)
        c{i} = num2str(v(i));
    end

    s = c{1};
    for i = 2:numel(c)
        s = [s sep c{i}]; %#ok<AGROW>
    end

end

function out = value_preview_char(v, maxChars)
%VALUE_PREVIEW_CHAR  Compact preview of a value (unused by default).

    try
        if ischar(v)
            out = v;

        elseif isnumeric(v) || islogical(v)
            if isempty(v)
                out = '';
            elseif isscalar(v)
                out = num2str(v);
            else
                out = sprintf('%s [%s] ...', class(v), join_num(size(v), 'x'));
            end

        elseif iscell(v)
            out = sprintf('cell{%d}', numel(v));

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
