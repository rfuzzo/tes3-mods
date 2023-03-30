use std::path::Path;

use mwscript::dump;

#[test]
fn test_dump() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");

    assert!(
        dump(
            &Some(input.into()),
            &Some(output.into()),
            false,
            &[],
            &[],
            &mwscript::ESerializedType::Yaml
        )
        .is_ok(),
        "error converting"
    );

    Ok(())
}
