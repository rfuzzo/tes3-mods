use std::path::Path;

use mwscript::dump_scripts;

#[test]
fn test_dump() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");

    assert!(
        dump_scripts(&Some(input.into()), &Some(output.into()), false).is_ok(),
        "error converting"
    );

    Ok(())
}
