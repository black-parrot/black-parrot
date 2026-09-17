# SATP write checks

`satp_write.tcl` verifies the SATP write guard in the patched `bp_be_csr` module with JasperGold. The checker is bound to the real RTL. No replacement CSR model or software stimulus is used.

The rejection properties require the complete architectural SATP value to remain unchanged before compression and after storage. They apply to every unsupported MODE encoding with unconstrained write data. Additional assertions check supported writes and preservation when SATP is not written. Bare positive controls use zero for the reserved fields.

Four explicit cover properties establish that rejection is reachable from both Bare and Sv39, with supported updates also reachable. JasperGold additionally checks assertion preconditions. The script fails if an expected assertion is unproven or an explicit cover is unreached.

Initialize `external/basejump_stl` and `external/HardFloat`. With JasperGold and its license configured, run from a scratch directory:

```sh
export BP_DIR=/path/to/patched/black-parrot
mkdir -p /path/to/scratch/satp-write
cd /path/to/scratch/satp-write
jg "$BP_DIR/bp_be/test/formal/satp_write.tcl" -batch -proj jgproject
```

Expected result: five assertions proven and four explicit covers reached. The default configuration was verified with JasperGold 2025.06; its summary includes five additional covered assertion preconditions. The checker also passes Verilator lint and VCS compilation. This checks CSR behavior at the RTL boundary. Full-core software execution is outside this test's scope.

NOTE: This flow was graciously contributed and 100% unsupported as maintainers do not have access to JasperGold. If you would like to donate JasperGold access, please contact us!

