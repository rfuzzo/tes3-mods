use std::{
    fs::{self, File},
    io::{self, Error, ErrorKind, Read, Write},
    path::{Path, PathBuf},
};
use tes3::esp::{Plugin, Script};

/// Dump all scripts from an esp into files
pub fn dump_scripts(input: &Option<PathBuf>, out_dir: Option<PathBuf>) -> std::io::Result<()> {
    // input
    if input.is_none() {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            "No input path specified.",
        ));
    }
    if let Some(ref i) = input {
        if !i.exists() {
            return Err(Error::new(
                ErrorKind::InvalidInput,
                "Input path does not exist",
            ));
        }
    }
    // what should be the default dump directory?
    // 1) the cwd
    // 2) the directory of the plugin
    let mut out_dir_path = PathBuf::from("");
    if let Some(p) = out_dir {
        out_dir_path = p;
    }
    if !out_dir_path.exists() {
        // create directory
        match fs::create_dir_all(&out_dir_path) {
            Ok(_) => {}
            Err(_) => {
                return Err(Error::new(
                    ErrorKind::Other,
                    "Failed to create output directory.",
                ));
            }
        }
    }

    // parse plugin
    let plugin = parse(input.as_ref().unwrap());

    // write
    match plugin {
        Ok(p) => {
            // find scripts
            for object in p.objects {
                if object.tag_str() == "SCPT" {
                    match write_script(object, &out_dir_path) {
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
                        //println!("File write failed: {}", err)
                        return Err(Error::new(ErrorKind::Other, "File write failed"));
                    }
                },
                Err(_) => {
                    //println!("File create failed: {}", err)
                    return Err(Error::new(ErrorKind::Other, "File create failed"));
                }
            }

            // let json = serde_json::to_string(&script);
            // match json {
            //     Ok(json_string) => {

            //     }
            //     Err(_) => {
            //         //println!("Json parsing of script failed: {}", err)
            //         return Err(Error::new(
            //             ErrorKind::Other,
            //             "Json parsing of script failed",
            //         ));
            //     }
            // }
        }
    } else {
        return Err(Error::new(ErrorKind::Other, "Script convert failed"));
    }

    Ok(())
}

/// Parse the contents of the given path into a TES3 Plugin.
/// Whether to parse as JSON or binary is inferred from first character.
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
