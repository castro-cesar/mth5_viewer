# MTH5 Viewer (MATLAB)

**MTH5 Viewer** is a MATLAB App Designer GUI to explore **MTH5/HDF5** files used in magnetotellurics (MT).  
It lets you browse the HDF5 hierarchy (groups/datasets/attributes), inspect metadata, preview datasets, and export a full tree into the MATLAB workspace.

Developed in **MATLAB R2024b**.

---

## What is MTH5?

**MTH5** is an HDF5-based container format for **magnetotelluric time-series** data and metadata.

If you want the authoritative description of the MTH5 data model and conventions, visit the upstream project:

- Official docs: https://mth5.readthedocs.io/en/latest/index.html  
- Source code: https://github.com/kujaku11/mth5  

---

## What this repository provides

### MTH5 Viewer features (current)
- Load an MTH5 file (`*.h5`) from the GUI (**File → Load → MTH5 file**)
- Tree browser for **groups / datasets / attributes**
  - datasets display: `name [size] <datatype>`
- Description panel:
  - groups: `h5info` summary (counts of groups/datasets/attrs)
  - datasets: size + datatype class
  - attributes: value preview + best-effort resolution of **HDF5 object references**
- Quick-look plot:
  - 1D datasets are read with **stride/downsampling** for speed
- Export:
  - **File → Export → to Workspace** exports a full MATLAB struct (can be large)

⚠️ **Note:** Export performs a **full dataset read** by default and may exceed memory on large files.

---

## Screenshot

![MTH5 Viewer screenshot](assets/screenshot_main1.png)

![MTH5 Viewer screenshot](assets/screenshot_main2.png)

---

## Run from source

1. Clone the repo
2. In MATLAB, run:

```matlab
setup_paths();
mth5_viewer
