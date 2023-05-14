use std::{
    env::consts::OS,
    fs::{self, File},
    io::{self, BufRead},
    path::{Path, PathBuf},
};

use log::{debug, error, info, warn};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct Manifest {
    pub files: Vec<PathBuf>,
}

/// Returns an Iterator to the Reader of the lines of the file.
pub(crate) fn read_lines<P>(filename: P) -> io::Result<io::Lines<io::BufReader<File>>>
where
    P: AsRef<Path>,
{
    let file = File::open(filename)?;
    Ok(io::BufReader::new(file).lines())
}

/// Parses the omwcfg and returns the data directories and content files
pub fn parse_cfg(cfg_path: PathBuf) -> Option<(Vec<PathBuf>, Vec<String>)> {
    let mut data_dirs: Vec<PathBuf> = vec![];
    let mut plugin_names: Vec<String> = vec![];

    info!("Parsing cfg {} ...", cfg_path.display());
    if let Ok(lines) = read_lines(&cfg_path) {
        for line in lines.flatten() {
            // parse each line
            if let Some(data_dir) = line.strip_prefix("data=") {
                // we found a data folder
                // add it to the folder list
                // we later copy all filtered plugins from that folder to the output_path
                let trimmed = data_dir.replace('"', "");
                let path = Path::new(trimmed.as_str()).to_path_buf();

                data_dirs.push(path);
            }

            if let Some(name) = line.strip_prefix("content=") {
                // we found a plugin name
                // add it to the plugin list
                // we filter later with that
                plugin_names.push(name.to_owned())
            }
        }

        Some((data_dirs, plugin_names))
    } else {
        error!("Could not parse cfg file {}", cfg_path.display());
        None
    }
}

/// Create a manifest of files to copy
///
/// # Panics
///
/// Panics if the self value equals None of a file in the cfg
pub fn create_manifest(data_dirs: Vec<PathBuf>, plugin_names: &[String]) -> Manifest {
    let mut manifest: Vec<PathBuf> = vec![];
    for path in data_dirs {
        if path.exists() {
            // get all plugins
            if let Ok(plugins) = fs::read_dir(path) {
                plugins.for_each(|p| {
                    if let Ok(file) = p {
                        let file_path = file.path();
                        if file_path.is_file() {
                            if let Some(ext) = file_path.extension() {
                                if ext == "esp" || ext == "omwaddon" || ext == "omwscripts" {
                                    // rust wtf :hidethepain:
                                    let file_name =
                                        file_path.file_name().unwrap().to_str().unwrap().to_owned();
                                    // check if the
                                    if plugin_names.contains(&file_name) {
                                        // add to manifest
                                        manifest.push(file_path);
                                    }
                                }
                            }
                        }
                    }
                });
            }
        } else {
            warn!("data path {} does not exist", path.display())
        }
    }
    Manifest { files: manifest }
}

/// Copies the files specified in the manifest to out_path
pub fn copy_files(manifest: &Vec<PathBuf>, out_path: &Path) -> Option<usize> {
    if !out_path.is_dir() {
        return None;
    }
    let mut count = 0;
    for file in manifest {
        // copy file
        if let Some(file_name) = file.file_name() {
            match fs::copy(file, out_path.join(file_name)) {
                Ok(_) => {
                    debug!("Copied {}", file.display());
                    count += 1;
                }
                Err(_) => {
                    warn!("Failed to copy {}", file.display());
                }
            }
        }
    }
    Some(count)
}

/// Copy plugins found in the openmw.cfg to specified directory, default is current working directory
pub fn export(
    in_path_option: &Option<PathBuf>,
    out_path_option: &Option<PathBuf>,
) -> Option<usize> {
    // checks for in dir
    let in_path: PathBuf;
    if let Some(path) = in_path_option {
        // checks
        if !path.exists() {
            error!("{} does not exist", path.display());
            return None;
        }
        if !path.is_file() {
            error!("{} is not a file", path.display());
            return None;
        }
        in_path = path.to_path_buf();
    } else {
        // get cfg from default path
        if let Some(path) = get_openmwcfg() {
            in_path = path;
        } else {
            error!("Could not find default openmw.cfg");
            return None;
        }
    }
    // checks for out dir
    let mut out_path = Path::new("");
    if let Some(path) = out_path_option {
        // checks
        if !path.exists() {
            error!("{} does not exist", path.display());
            return None;
        }
        if !path.is_dir() {
            error!("{} is not a directory", path.display());
            return None;
        }
        out_path = path;
    }

    // parse cfg for data dirs
    let result = parse_cfg(in_path);
    let Some((data_dirs ,plugin_names)) = result else { return None; };
    info!("Found {} data dirs", data_dirs.len());
    info!("Found {} plugins", plugin_names.len());

    // create a manifest of files to copy
    info!("Creating manifest ...");
    let manifest = create_manifest(data_dirs, &plugin_names);
    if manifest.files.len() == plugin_names.len() {
        info!("All plugins accounted for");
    } else {
        warn!("Not all content plugins found in the data directories!")
    }

    // and save the manifest as toml
    match toml::to_string_pretty(&manifest) {
        Ok(toml) => {
            let manifest_path = out_path.join("omw-util.manifest");
            if let Ok(_write_result) = fs::write(manifest_path, toml.as_bytes()) {
                info!("Saved manifest file to {}", out_path.display());
            } else {
                warn!("Could not save manifest file");
            }
        }
        Err(err) => {
            warn!("Could not create manifest file: {}", err);
        }
    }

    // now copy the actual files
    info!("Copying files to {} ...", out_path.display());
    let copy_result = copy_files(&manifest.files, out_path);
    if let Some(count) = copy_result {
        info!("Copied {} files", count);
        if count == manifest.files.len() {
            info!("All files accounted for");
            return Some(count);
        } else {
            warn!("Could not copy all files!")
        }
    } else {
        error!("Could not copy any files!")
    }

    None
}

/// Returns the default openmw.cfg path if it exists, and None if not
///
/// # Panics
///
/// Panics if Home dir is not found in the OS
fn get_openmwcfg() -> Option<PathBuf> {
    let os_str = OS;
    match os_str {
        "linux" => {
            todo!();
        }
        "macos" => {
            // default cfg for mac is at $HOME/Library/Preferences/openmw
            let home = dirs::home_dir().unwrap();
            let cfg = home
                .join("Library")
                .join("Preferences")
                .join("openmw")
                .join("openmw.cfg");
            if cfg.exists() {
                Some(cfg)
            } else {
                None
            }
        }
        "windows" => {
            todo!()
        }
        _ => None,
    }
}
