# MTH5 Viewer (MATLAB)

A MATLAB App Designer GUI to explore **MTH5/HDF5** files used in magnetotellurics (MT): browse the HDF5 hierarchy, inspect attributes/metadata, preview datasets, and export contents to the MATLAB workspace.

Official MTH5 documentation (upstream project):
https://mth5.readthedocs.io/en/latest/index.html

---

## Status
- Developed in **MATLAB R2024b**
- Distribution options:
  - Run from source (`mth5_viewer.m`)
  - Packaged App (`.mlapp`) for installation via MATLAB Apps

---

## Quick start (from source)
1. Clone this repository
2. In MATLAB, add the repo folders to your path:
   - `app/`
   - `src/`
3. Run:
   - `mth5_viewer`

---

## What the Viewer does
- Load an MTH5 file (`*.h5`) from the UI
- Browse groups / datasets / attributes in a tree
- Display dataset metadata (size, datatype) and group summary (counts)
- Plot 1D datasets using a downsampled read (stride) for speed
- Best-effort resolution of HDF5 object references in attributes
- Export full file tree to the MATLAB workspace (can be large)

---

## Documentation
GitHub Pages: https://castro-cesar.github.io/mth5_viewer/

---

## License
TBD
