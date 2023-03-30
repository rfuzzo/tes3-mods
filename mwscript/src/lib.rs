use clap::ValueEnum;
use std::{
    fmt,
    fs::{self, File},
    io::{self, Error, ErrorKind, Read, Write},
    path::{Path, PathBuf},
};
use tes3::esp::{Plugin, Script, TES3Object};

#[derive(Default, Clone, ValueEnum)]
pub enum ESerializedType {
    #[default]
    Yaml,
    Toml,
}
impl fmt::Display for ESerializedType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            ESerializedType::Yaml => write!(f, "yaml"),
            ESerializedType::Toml => write!(f, "toml"),
        }
    }
}

/// Dump data from an esp into files
pub fn dump(
    input: &Option<PathBuf>,
    out_dir: &Option<PathBuf>,
    create: bool,
    include: &[String],
    exclude: &[String],
    serialized_type: &ESerializedType,
) -> std::io::Result<()> {
    let mut is_file = false;
    let mut is_dir = false;

    let input_path: &PathBuf;
    // check no input
    if let Some(i) = input {
        input_path = i;
    } else {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            "No input path specified.",
        ));
    }
    // check input path exists and check if file or directory
    if !input_path.exists() {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            "Input path does not exist",
        ));
    } else if input_path.is_file() {
        let ext = input_path.extension();
        if let Some(e) = ext {
            let e_str = e.to_str().unwrap().to_lowercase();
            if e_str == "esp" || e_str == "omwaddon" {
                is_file = true;
            }
        }
    } else if input_path.is_dir() {
        is_dir = true;
    }

    // check output path, default is cwd
    let mut out_dir_path = &PathBuf::from("");
    if let Some(p) = out_dir {
        out_dir_path = p;
    }

    // dump plugin file
    if is_file {
        if create {
            match dump_plugin(
                input_path,
                &out_dir_path.join(input_path.file_stem().unwrap()),
                include,
                exclude,
                serialized_type,
            ) {
                Ok(_) => {}
                Err(e) => return Err(e),
            }
        } else {
            match dump_plugin(input_path, out_dir_path, include, exclude, serialized_type) {
                Ok(_) => {}
                Err(e) => return Err(e),
            }
        }
    }

    // dump folder
    // input is a folder, it may contain many plugins (a.esp, b.esp)
    // dumps scripts into cwd/a/ and cwd/b
    // check if already exists?
    if is_dir {
        // get all plugins non-recursively
        let paths = fs::read_dir(input_path).unwrap();
        for entry in paths.flatten() {
            let path = entry.path();
            if path.is_file() && path.exists() {
                let ext = path.extension();
                if let Some(e) = ext {
                    let e_str = e.to_str().unwrap().to_lowercase();

                    if e_str == "esp" || e_str == "omwaddon" {
                        // dump scripts into folders named after the plugin name
                        let plugin_name = path.file_stem().unwrap();
                        let out_path = &out_dir_path.join(plugin_name);

                        match dump_plugin(&path, out_path, include, exclude, serialized_type) {
                            Ok(_) => {}
                            Err(e) => return Err(e),
                        }
                    }
                }
            }
        }
    }

    Ok(())
}

/// Dumps one plugin
fn dump_plugin(
    input: &PathBuf,
    out_dir_path: &Path,
    include: &[String],
    exclude: &[String],
    typ: &ESerializedType,
) -> Result<(), Error> {
    let plugin = parse(input);
    // parse plugin
    // write
    match plugin {
        Ok(p) => {
            for object in p.objects {
                // if (!include.is_empty() && include.contains(&object.tag_str().to_owned()))
                //     && !exclude.contains(&object.tag_str().to_owned())
                {
                    write_object(&object, out_dir_path, typ);
                }
            }
        }
        Err(_) => {
            return Err(Error::new(ErrorKind::Other, "Plugin parsing failed."));
        }
    }
    Ok(())
}

fn write_object(object: &TES3Object, out_dir_path: &Path, serialized_type: &ESerializedType) {
    match object {
        TES3Object::Header(_) => {}      // do not dump the header
        TES3Object::Landscape(_) => {}   // not implemented
        TES3Object::PathGrid(_) => {}    // not implemented
        TES3Object::Skill(_) => {}       // not implemented
        TES3Object::MagicEffect(_) => {} // not implemented
        TES3Object::Script(script) => {
            write_script(script, &out_dir_path.join("Script"))
                .unwrap_or_else(|_| panic!("Writing failed: {}", script.id));
        }
        TES3Object::GameSetting(_)
        | TES3Object::GlobalVariable(_)
        | TES3Object::Class(_)
        | TES3Object::Faction(_)
        | TES3Object::Race(_)
        | TES3Object::Sound(_)
        | TES3Object::Region(_)
        | TES3Object::Birthsign(_)
        | TES3Object::StartScript(_)
        | TES3Object::LandscapeTexture(_)
        | TES3Object::Spell(_)
        | TES3Object::Static(_)
        | TES3Object::Door(_)
        | TES3Object::MiscItem(_)
        | TES3Object::Weapon(_)
        | TES3Object::Container(_)
        | TES3Object::Creature(_)
        | TES3Object::Bodypart(_)
        | TES3Object::Light(_)
        | TES3Object::Enchanting(_)
        | TES3Object::Npc(_)
        | TES3Object::Armor(_)
        | TES3Object::Clothing(_)
        | TES3Object::RepairItem(_)
        | TES3Object::Activator(_)
        | TES3Object::Apparatus(_)
        | TES3Object::Lockpick(_)
        | TES3Object::Probe(_)
        | TES3Object::Ingredient(_)
        | TES3Object::Book(_)
        | TES3Object::Alchemy(_)
        | TES3Object::LeveledItem(_)
        | TES3Object::LeveledCreature(_)
        | TES3Object::SoundGen(_)
        | TES3Object::Dialogue(_)
        | TES3Object::Info(_)
        | TES3Object::Cell(_) => {
            let (nam, typ) = get_name(object);
            let name = format!("{}.{}", nam, serialized_type);
            write_generic(object, &name, &out_dir_path.join(typ), serialized_type)
                .unwrap_or_else(|_| panic!("Writing failed: {}", name));
        }
    }
}

fn get_name(object: &TES3Object) -> (String, &str) {
    match object {
        TES3Object::Header(_) => todo!(),
        TES3Object::GameSetting(o) => (o.id.to_string(), o.type_name()),
        TES3Object::GlobalVariable(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Class(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Faction(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Race(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Sound(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Skill(_) => todo!(),
        TES3Object::MagicEffect(_) => todo!(),
        TES3Object::Script(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Region(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Birthsign(o) => (o.id.to_string(), o.type_name()),
        TES3Object::StartScript(o) => (o.id.to_string(), o.type_name()),
        TES3Object::LandscapeTexture(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Spell(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Static(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Door(o) => (o.id.to_string(), o.type_name()),
        TES3Object::MiscItem(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Weapon(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Container(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Creature(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Bodypart(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Light(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Enchanting(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Npc(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Armor(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Clothing(o) => (o.id.to_string(), o.type_name()),
        TES3Object::RepairItem(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Activator(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Apparatus(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Lockpick(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Probe(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Ingredient(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Book(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Alchemy(o) => (o.id.to_string(), o.type_name()),
        TES3Object::LeveledItem(o) => (o.id.to_string(), o.type_name()),
        TES3Object::LeveledCreature(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Cell(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Landscape(_) => todo!(),
        TES3Object::PathGrid(_) => todo!(),
        TES3Object::SoundGen(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Dialogue(o) => (o.id.to_string(), o.type_name()),
        TES3Object::Info(o) => (o.id.to_string(), o.type_name()),
    }
}

/// Write a tes3object script to a file
fn write_script(script: &Script, out_dir: &Path) -> std::io::Result<()> {
    if !out_dir.exists() {
        // create directory
        match fs::create_dir_all(out_dir) {
            Ok(_) => {}
            Err(_) => {
                return Err(Error::new(
                    ErrorKind::Other,
                    "Failed to create output directory.",
                ));
            }
        }
    }

    // get name
    let name = format!("{}.mwscript", script.id);
    // get script plaintext
    if let Some(plain) = &script.script_text {
        // write to file
        let output_path = out_dir.join(name);
        let file_or_error = File::create(&output_path);
        match file_or_error {
            Ok(mut file) => match file.write_all(plain.as_bytes()) {
                Ok(_) => {
                    // todo verbosity
                    println!("SCPT writen to: {}", output_path.display());
                }
                Err(_) => {
                    return Err(Error::new(ErrorKind::Other, "File write failed"));
                }
            },
            Err(_) => {
                return Err(Error::new(ErrorKind::Other, "File create failed"));
            }
        }
    }

    Ok(())
}

/// Write a generic tes3object to a file
fn write_generic(
    object: &TES3Object,
    name: &String,
    out_dir: &Path,
    typ: &ESerializedType,
) -> std::io::Result<()> {
    if !out_dir.exists() {
        // create directory
        match fs::create_dir_all(out_dir) {
            Ok(_) => {}
            Err(_) => {
                return Err(Error::new(
                    ErrorKind::Other,
                    "Failed to create output directory.",
                ));
            }
        }
    }

    // serialize
    let text = match typ {
        ESerializedType::Yaml => {
            let y = serde_yaml::to_string(&object);
            y.unwrap()
        }
        ESerializedType::Toml => {
            let t = toml::to_string(&object);
            t.unwrap()
        }
    };

    // write to file
    let output_path = out_dir.join(name);
    let file_or_error = File::create(&output_path);
    match file_or_error {
        Ok(mut file) => match file.write_all(text.as_bytes()) {
            Ok(_) => {
                // todo verbosity
                println!("MISC writen to: {}", output_path.display());
                Ok(())
            }
            Err(_) => Err(Error::new(ErrorKind::Other, "File write failed")),
        },
        Err(_) => Err(Error::new(ErrorKind::Other, "File create failed")),
    }
}

/// Parse the contents of the given path into a TES3 Plugin.
/// Whether to parse as JSON or binary is inferred from first character.
/// taken from: https://github.com/Greatness7/tes3conv
fn parse(path: &PathBuf) -> io::Result<Plugin> {
    let mut raw_data = vec![];
    File::open(path)?.read_to_end(&mut raw_data)?;

    let mut plugin = Plugin::new();

    match raw_data.first() {
        Some(b'T') => {
            // if it starts with a 'T' assume it's a TES3 file
            plugin.load_bytes(&raw_data)?;
        }
        _ => {
            // anything else is guaranteed to be invalid input
            return Err(io::Error::new(io::ErrorKind::InvalidData, "Invalid input."));
        }
    }

    // sort objects so that diffs are a little more useful
    //plugin.sort();    //TODO

    Ok(plugin)
}
