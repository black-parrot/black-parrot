# make & view coverage reports
##### 1. To monitor coverage, include `COVERAGE=VCS` option during simulation.
For instance:
```
    $ make TEST_ROM=median_rom.v TRACE_ROM=median_rom.tr.v COVERAGE=VCS bp_single_trace_demo.run.v
```
##### 2. To generate coverage reports, run the following command:
```
    $ make COVERAGE=VCS urg
```
This command will generate reports in both html and txt format.
You can view reports in `bp_top/syn/coverage_reports` folder.

##### 3. Editing signal and module coverage of Coverage reports
In file `coverage.hier`, I specify signals excluded from coveage report.