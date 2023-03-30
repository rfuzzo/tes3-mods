use std::path::Path;

use mwscript::dump;

#[test]
fn test_dump_yaml() -> std::io::Result<()> {
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

#[test]
fn test_dump_toml() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");

    assert!(
        dump(
            &Some(input.into()),
            &Some(output.into()),
            false,
            &[],
            &[],
            &mwscript::ESerializedType::Toml
        )
        .is_ok(),
        "error converting"
    );

    Ok(())
}

#[test]
fn test_dump_json() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");

    assert!(
        dump(
            &Some(input.into()),
            &Some(output.into()),
            false,
            &[],
            &[],
            &mwscript::ESerializedType::Json
        )
        .is_ok(),
        "error converting"
    );

    Ok(())
}
