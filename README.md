# mth5_viewer — MTH5 Viewer (MATLAB)

A MATLAB App Designer GUI to browse **MTH5/HDF5** files used in magnetotellurics (MT): explore the HDF5 hierarchy, inspect attributes/metadata, preview datasets, and export contents to the MATLAB workspace.

Developed in **MATLAB R2024b**.

---

## What is an MTH5 file?

**MTH5** is an HDF5-based container format for **magnetotelluric (MT) time-series** data and associated metadata.  
In practice, an MTH5 file is a standard **HDF5 file** (`*.h5`) that stores:

- **Groups** (HDF5 groups): hierarchical folders that organize the content
- **Datasets** (HDF5 datasets): numeric arrays (time series, derived products, etc.)
- **Attributes**: key–value metadata attached to groups/datasets (station/run info, sampling parameters, units, processing details, etc.)

Because MTH5 is HDF5, files can be **very large** (full time-series across many channels/runs), and some metadata may be stored as:
- **HDF5 object references** (attributes that point to other objects inside the file)

This viewer is designed to make these structures inspectable quickly from MATLAB.

### Typical structure (conceptually)
MTH5 commonly follows how MT data are collected:
- survey → stations → runs → channels (and related metadata)

Exact group naming and conventions are defined by the upstream MTH5 project.

---

## What this Viewer provides

### Current features (implemented)
- **Load** MTH5 file (`*.h5`) from the UI: `File → Load → MTH5 file (*.h5)`
- **Tree browser** (groups / datasets / attributes)
  - datasets display: `name [size] <datatype>`
- **Description panel**
  - group nodes: counts of groups/datasets/attributes via `h5info`
  - dataset nodes: size + datatype class via `h5info`
  - attribute nodes: value preview + best-effort **HDF5 reference resolution**
- **Quick-look plot**
  - 1D datasets are read using a **stride/downsample** for plotting (to avoid loading the full vector)
- **Export to Workspace**
  - `File → Export → to Workspace`
  - runs a full-read exporter (`mth5_export`) and assigns `tree` into MATLAB base workspace

⚠️ **Note on memory:** `mth5_export` is a **FULL READ** by default (datasets read with `h5read`). Large files can exceed memory. Use it intentionally.

---

## Repository layout (current)

```text
MTH5Viewer/
├─ GUI/         # App Designer GUI (mth5_viewer)
├─ Functions/   # loaders/exporters/tree helpers/callbacks
└─ Extras/      # icons + logo assets
   ├─ Icons/
   └─ Logo/
```

---

## Getting started (from source)

1. Clone the repository
2. Add folders to the MATLAB path (example):

```matlab
root = "C:\path\to\MTH5Viewer";
addpath(fullfile(root, "GUI"));
addpath(fullfile(root, "Functions"));
addpath(fullfile(root, "Extras"));
addpath(fullfile(root, "Extras", "Icons"));
addpath(fullfile(root, "Extras", "Logo"));
```

3. Run:

```matlab
mth5_viewer
```

---

## Packaging as an App

This project can also be distributed as a MATLAB App (`.mlapp`) via App Designer packaging.  
(If you publish releases, place the `.mlappinstall` under GitHub Releases and document the steps here.)

---

## Documentation

### This repo (GitHub Pages)
- https://<your-github-user>.github.io/mth5_viewr/

### Upstream MTH5 (official)
- Docs: https://mth5.readthedocs.io/en/latest/index.html
- Source (GitHub): https://github.com/kujaku11/mth5
- USGS software release page: https://www.usgs.gov/software/mth5-archivable-and-exchangeable-hdf5-format-magnetotelluric-data

---

## How to cite MTH5

Peacock, J. R., Kappler, K., Heagy, L., Ronan, T., Kelbert, A., & Frassetto, A. (2022).  
**MTH5: An archive and exchangeable data format for magnetotelluric time series data.**  
Computers & Geosciences, 162, 105102. https://doi.org/10.1016/j.cageo.2022.105102

USGS publication entry:
https://www.usgs.gov/publications/mth5-archive-and-exchangeable-data-format-magnetotelluric-time-series-data

---

## License

MIT License (see `LICENSE`).

