function setup_paths()
% SETUP_PATHS  Add mth5_viewer folders to the MATLAB path (run once per session).
% -------------------------------------------------------------------------
% Usage:
%   setup_paths();
%   mth5_viewer
%
% This adds the GUI, Functions, and Extras (icons/logo) folders so that:
% - the app entry point is found
% - helper functions are found
% - UI icons can be resolved via `which()` (e.g., group.png, dataset.png, attribute.png)
%
% Developed for MATLAB R2024b.
% -------------------------------------------------------------------------
%   Author: César Castro
%   Last update: 06-Jan-2026
% -------------------------------------------------------------------------

    root = fileparts(mfilename('fullpath'));

    % Core folders
    addpath(fullfile(root, 'GUI'));
    addpath(fullfile(root, 'Functions'));

    % Assets (icons/logo)
    addpath(fullfile(root, 'Extras'));
    addpath(fullfile(root, 'Extras', 'Icons'));
    addpath(fullfile(root, 'Extras', 'Logo'));

end