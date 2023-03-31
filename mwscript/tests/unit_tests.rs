use tes3::esp::Plugin;

#[test]
fn test_serialize_to_yaml() -> std::io::Result<()> {
    let plugin = Plugin::from_path("tests/assets/Ashlander Crafting.ESP")?;
    let _ = serde_yaml::to_string(&plugin).unwrap();
    Ok(())
}
#[test]
fn test_serialize_to_toml() -> std::io::Result<()> {
    let plugin = Plugin::from_path("tests/assets/Ashlander Crafting.ESP")?;
    let _ = toml::to_string(&plugin).unwrap();
    Ok(())
}
#[test]
fn test_serialize_to_json() -> std::io::Result<()> {
    let plugin = Plugin::from_path("tests/assets/Ashlander Crafting.ESP")?;
    let _ = serde_json::to_string(&plugin).unwrap();
    Ok(())
}

#[test]
fn test_deserialize_from_yaml() {
    let plugin = Plugin::from_path("tests/assets/Ashlander Crafting.ESP").unwrap();
    let text = serde_yaml::to_string(&plugin).unwrap();
    let deserialized: Result<Plugin, _> = serde_yaml::from_str(&text);
    assert!(deserialized.is_ok());
}
#[test]
fn test_deserialize_from_toml() {
    let plugin = Plugin::from_path("tests/assets/Ashlander Crafting.ESP").unwrap();
    let text = toml::to_string(&plugin).unwrap();
    let deserialized: Result<Plugin, _> = toml::from_str(&text);
    assert!(deserialized.is_ok());
}
#[test]
fn test_deserialize_from_json() {
    let plugin = Plugin::from_path("tests/assets/Ashlander Crafting.ESP").unwrap();
    let text = serde_json::to_string(&plugin).unwrap();
    let deserialized: Result<Plugin, _> = serde_json::from_str(&text);
    assert!(deserialized.is_ok());
}
