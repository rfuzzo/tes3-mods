use std::{
    fs::{self, File},
    io::{self, Error, ErrorKind, Read, Write},
    path::{Path, PathBuf},
};
use tes3::esp::{Plugin, Script};

/// Dump all scripts from an esp into files
pub fn dump_scripts(
    input: &Option<PathBuf>,
    out_dir: &Option<PathBuf>,
    create: bool,
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
            match dump_plugin_scripts(
                input_path,
                &out_dir_path.join(input_path.file_stem().unwrap()),
            ) {
                Ok(_) => {}
                Err(e) => return Err(e),
            }
        } else {
            match dump_plugin_scripts(input_path, out_dir_path) {
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

                        match dump_plugin_scripts(&path, out_path) {
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
fn dump_plugin_scripts(input: &PathBuf, out_dir_path: &Path) -> Result<(), Error> {
    let plugin = parse(input);
    // parse plugin
    // write
    match plugin {
        Ok(p) => {
            // find scripts
            for object in p.objects {
                if object.tag_str() == "SCPT" {
                    match write_script(object, out_dir_path) {
                        Ok(_) => {}
                        Err(e) => return Err(e),
                    }
                }
            }
        }
        Err(_) => {
            return Err(Error::new(ErrorKind::Other, "Plugin parsing failed."));
        }
    }
    Ok(())
}

/// Write a tes3object script to a file
fn write_script(object: tes3::esp::TES3Object, out_dir: &Path) -> std::io::Result<()> {
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
    let script_or_error: Result<Script, ()> = object.try_into();
    if let Ok(script) = script_or_error {
        let name = format!("{}.mwscript", script.id);
        // serialize to json
        if let Some(plain) = script.script_text {
            // write to file
            let output_path = out_dir.join(name);
            let file_or_error = File::create(&output_path);
            match file_or_error {
                Ok(mut file) => match file.write_all(plain.as_bytes()) {
                    Ok(_) => {
                        println!("Script writen to: {}", output_path.display());
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
    } else {
        return Err(Error::new(ErrorKind::Other, "Script convert failed"));
    }

    Ok(())
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
