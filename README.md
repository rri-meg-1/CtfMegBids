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

# License checks

GitHub Actions checks pull requests to `main` and pushes to any branch, so checks
can pass before a manual fast-forward. The `License declarations` check verifies
that `LICENSE` matches the verified GNU GPLv3 text and each root-level MATLAB file has a
`GPL-3.0-only` SPDX identifier in its opening comments. Run it locally with:

```sh
python3 .github/scripts/check_licenses.py
```

The separate `ScanCode report` job scans all tracked files, including third-party
code. Download the `scancode-report` artifact from the workflow run for HTML and
JSON findings. Findings are informational; scanner execution errors fail that
job. New third-party code and changes to licensing still require human review.

Configure `License declarations` as a required status check in the GitHub `main`
ruleset to block merging when it fails. Keep `ScanCode report` optional until
the existing findings have been reviewed. Ruleset bypass permissions still apply.
