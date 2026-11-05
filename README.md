# CtfMegBids
Matlab code for converting and managing CTF MEG recordings into BIDS

Marc Lalancette, Montreal Neurological Institute-Hospital, McGill University

# Usage
Runs on raw CTF MEG acquisition folders and moves all datasets (.ds) and
optional adjoining files (.pos, .log, .jpg) into a specified BIDS directory, or
into the parent folder ("/CTF-acquisition" in the following example):
`MegToBids('/CTF-acquisition/20250101');`

See MegToBids.m for further usage documentation.

Can run from the operating system command line, e.g.:
matlab -batch "MegToBids('/CTF-acquisition/20250101');"

# License

The root-level MATLAB files in this fork are distributed under the GNU General
Public License version 3 (`GPL-3.0-only`), with permission from Marc Lalancette.
See [LICENSE](LICENSE) for the full license text. Each file carries a short SPDX
license identifier.

Existing author, copyright, and license notices are preserved. The embedded
`openmrk` helper in `BidsBuildRecordingFiles.m` retains its GPLv3-or-later grant.
Third-party code in `BstDependencies/` and `heudiconv_bids.py` retains its upstream
licensing terms; the root MATLAB SPDX declarations do not relicense those files.
