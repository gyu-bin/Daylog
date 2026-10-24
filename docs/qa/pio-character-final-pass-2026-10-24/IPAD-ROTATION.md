# iPad rotation / desktop control

PARTIAL / NOT_VERIFIED. iPad actual native portrait/AX scroll reaches content end, but requestGeometryUpdate did not produce the requested landscape scene orientation in two recorded fixtures. We did not replace this with a synthetic landscape PASS. Logs: ipad-tests.log, ipad-recheck-tests.log. First fixture reused host bounds; second explicitly observed actual UIWindowScene.interfaceOrientation and still failed. App orientation configuration was not changed.

Desktop-control fallback followed computer-use skill /Users/mungyubin/.agents/skills/computer-use/SKILL.md. Its discovery rule says: “If the selected executable cannot run, report its exact error and stop. Do not fall through to another executable”. ORCA_CLI_COMMAND and ORCA_DEV_REPO_ROOT absent; selected executable orca. `orca skills get computer-use` returned zsh:1: command not found: orca, exit127. Orca menu-control work stopped; unrelated implementation and native screenshot/testing continued. This does not establish an app rotation defect or full iPad QA PASS.


Final portrait validation: `ipad-portrait-final-attachments/manifest.json` contains 12 current C7 portrait PNGs; the portrait screen capture test passed 1/1. All 12 were directly inspected (home, cloud receiving/ready/trouble, vacation day/night, normal/AX5). Body, sprout, hammock and props remain intact after the planar correction. This supersedes the earlier 3D rendering failure for these portrait views only. It was not a rotation retry and does not change the landscape rotation PARTIAL / NOT_VERIFIED verdict above.
