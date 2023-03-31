use std::path::Path;

use mwscript::{deserialize_plugin, dump, pack, serialize_plugin, ESerializedType};

#[test]
fn test_serialize_to_yaml() -> std::io::Result<()> {
    let input = Path::new("tests/assets/Ashlander Crafting.ESP");
    serialize_plugin(&Some(input.into()), &None, &ESerializedType::Yaml)
}
#[test]
fn test_serialize_to_toml() -> std::io::Result<()> {
    let input = Path::new("tests/assets/Ashlander Crafting.ESP");
    serialize_plugin(&Some(input.into()), &None, &ESerializedType::Toml)
}
#[test]
fn test_serialize_to_json() -> std::io::Result<()> {
    let input = Path::new("tests/assets/Ashlander Crafting.ESP");
    serialize_plugin(&Some(input.into()), &None, &ESerializedType::Json)
}

#[test]
fn test_deserialize_from_yaml() -> std::io::Result<()> {
    let input = Path::new("tests/assets/Ashlander Crafting.ESP.yaml");
    deserialize_plugin(&Some(input.into()), &None)
}
#[test]
fn test_deserialize_from_toml() -> std::io::Result<()> {
    let input = Path::new("tests/assets/Ashlander Crafting.ESP.toml");
    deserialize_plugin(&Some(input.into()), &None)
}
#[test]
fn test_deserialize_from_json() -> std::io::Result<()> {
    let input = Path::new("tests/assets/Ashlander Crafting.ESP.json");
    deserialize_plugin(&Some(input.into()), &None)
}

#[test]
fn test_dump_yaml() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");
    dump(
        &Some(input.into()),
        &Some(output.into()),
        false,
        &[],
        &[],
        &ESerializedType::Yaml,
    )
}
#[test]
fn test_dump_toml() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");
    dump(
        &Some(input.into()),
        &Some(output.into()),
        false,
        &[],
        &[],
        &mwscript::ESerializedType::Toml,
    )
}
#[test]
fn test_dump_json() -> std::io::Result<()> {
    let input = Path::new("tests/assets");
    let output = Path::new("tests/assets/out");
    dump(
        &Some(input.into()),
        &Some(output.into()),
        false,
        &[],
        &[],
        &ESerializedType::Json,
    )
}

#[test]
fn test_pack_yaml() -> std::io::Result<()> {
    let input = Path::new("tests/assets/out/Ashlander Crafting");
    pack(input, None, &ESerializedType::Yaml)
}
#[test]
fn test_pack_toml() -> std::io::Result<()> {
    let input = Path::new("tests/assets/out/Ashlander Crafting");
    pack(input, None, &ESerializedType::Toml)
}
#[test]
fn test_pack_json() -> std::io::Result<()> {
    let input = Path::new("tests/assets/out/Ashlander Crafting");
    pack(input, None, &ESerializedType::Json)
}
