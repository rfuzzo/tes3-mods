use std::{
    env::consts::OS,
    fs::{self, File},
    io::{self, BufRead, Write},
    path::{Path, PathBuf},
};

use log::{debug, error, info, warn};
use serde::{Deserialize, Serialize};

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct Manifest {
    pub files: Vec<String>,
    pub existing_files: Vec<String>,
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
/// Panics if a filename can't be read
pub fn get_plugins(data_dirs: Vec<PathBuf>, plugin_names: &[String]) -> Vec<PathBuf> {
    let mut manifest: Vec<PathBuf> = vec![];
    for path in data_dirs {
        if path.exists() {
            let files = get_plugins_in_folder(&path);
            for file_path in files {
                // check if the plugin is in the active plugins list
                // rust wtf :hidethepain:
                let file_name = file_path.file_name().unwrap().to_str().unwrap().to_owned();
                if plugin_names.contains(&file_name) {
                    // add to manifest
                    manifest.push(file_path);
                }
            }
        } else {
            warn!("data path {} does not exist", path.display())
        }
    }
    manifest
}

/// Get all plugins (esp, omwaddon, omwscripts) in a folder
fn get_plugins_in_folder(path: &Path) -> Vec<PathBuf> {
    // get all plugins
    let mut results: Vec<PathBuf> = vec![];
    if let Ok(plugins) = fs::read_dir(path) {
        plugins.for_each(|p| {
            if let Ok(file) = p {
                let file_path = file.path();
                if file_path.is_file() {
                    if let Some(ext) = file_path.extension() {
                        if ext == "esm" || ext == "esp" || ext == "omwaddon" || ext == "omwscripts"
                        {
                            results.push(file_path);
                        }
                    }
                }
            }
        });
    }
    results
}

/// Copies files to out_path
pub fn copy_files(
    in_files: &Vec<PathBuf>,
    out_path: &Path,
    manifest: &mut Manifest,
    verbose: bool,
) {
    let mut existing: Vec<String> = vec![];
    let mut result: Vec<String> = vec![];
    for file in in_files {
        // copy file
        if let Some(file_name) = file.file_name() {
            let new_path = out_path.join(file_name);
            // if the working dir is the same as the data files dir
            // we will save the existing files to the manifest
            // this can be used later to prevent deleting existing files
            if file == &new_path {
                warn!(
                    "Working directory is equal to mod directory. {} not copied",
                    file_name.to_string_lossy()
                );
                result.push(file_name.to_string_lossy().into_owned());
                existing.push(file_name.to_string_lossy().into_owned()); // duplicate here to retain the correct order
            } else {
                match fs::copy(file, &new_path) {
                    Ok(_) => {
                        if verbose {
                            debug!("Copied {}", file.display());
                        }

                        result.push(file_name.to_string_lossy().into_owned());
                    }
                    Err(_) => {
                        warn!("Failed to copy {}", file.display());
                    }
                }
            }
        }
    }
    manifest.files = result;
    manifest.existing_files = existing;
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
            // default cfg for linux is at $HOME/.config/openmw
            let preference_dir = dirs::config_dir().unwrap();
            let cfg = preference_dir.join("openmw.cfg");
            if cfg.exists() {
                Some(cfg)
            } else {
                None
            }
        }
        "macos" => {
            // default cfg for mac is at /Users/Username/Library/Preferences/openmw
            let preference_dir = dirs::preference_dir().unwrap();
            let cfg = preference_dir.join("openmw").join("openmw.cfg");
            if cfg.exists() {
                Some(cfg)
            } else {
                None
            }
        }
        "windows" => {
            // default cfg for windows is at C:\Users\Username\Documents\my games\openmw
            let preference_dir = dirs::document_dir().unwrap();
            let cfg = preference_dir
                .join("my games")
                .join("openmw")
                .join("openmw.cfg");
            if cfg.exists() {
                Some(cfg)
            } else {
                None
            }
        }
        _ => None,
    }
}

/// Checks an input path and returns the default cfg if its not valid
fn check_cfg_path(in_path_option: Option<PathBuf>) -> Option<PathBuf> {
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
        in_path = path;
    } else {
        // get cfg from default path
        if let Some(path) = get_openmwcfg() {
            in_path = path;
        } else {
            error!("Could not find default openmw.cfg");
            return None;
        }
    }
    Some(in_path)
}

/// Copy plugins found in the openmw.cfg to specified directory, default is current working directory
pub fn export(
    cfg_path_option: Option<PathBuf>,
    out_path_option: Option<PathBuf>,
    verbose: bool,
) -> Option<usize> {
    // checks
    let in_path = match check_cfg_path(cfg_path_option) {
        Some(value) => value,
        None => return None,
    };
    let mut out_path = Path::new("./")
        .canonicalize()
        .expect("Could not expand relative path");
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
    let plugins_to_copy = get_plugins(data_dirs, &plugin_names);
    if plugins_to_copy.len() == plugin_names.len() {
        info!("All plugins accounted for");
    } else {
        warn!("Not all content plugins found in the data directories!")
    }

    // now copy the actual files
    let mut manifest = Manifest::default();
    info!("Copying files to {} ...", out_path.display());
    copy_files(&plugins_to_copy, &out_path, &mut manifest, verbose);

    info!("Processed {} files", manifest.files.len());
    info!("Found {} existing files", manifest.existing_files.len());

    // save the manifest as toml
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

    // modify the vanilla ini with the plugins
    let ini_path = out_path
        .parent()
        .expect("No Data File parent folder")
        .join("Morrowind.ini");
    info!("Parsing morrowind.ini {} ...", ini_path.display());
    let mut original_ini: Vec<String> = vec![];
    if let Ok(lines) = read_lines(&ini_path) {
        for line in lines.flatten() {
            // parse each line
            if !line.starts_with("GameFile") {
                original_ini.push(line);
            }
        }
    } else {
        error!("Could not parse ini file {}", ini_path.display());
        return None;
    }
    // reassemble ini
    if let Ok(mut file) = File::create(&ini_path) {
        // write original lines
        for line in original_ini {
            // TODO proper eol
            let line_with_eol = format!("{}\n", line);
            match file.write(line_with_eol.as_bytes()) {
                Ok(_) => {}
                Err(err) => warn!("Error writing line {}: {}", line, err),
            }
        }
        // write plugins
        // get existing and copied files
        let mut count = 0;
        for (i, p) in manifest.files.iter().enumerate() {
            // TODO proper eol
            let content_line = format!("GameFile{}={}\n", i, p);
            match file.write(content_line.as_bytes()) {
                Ok(_) => {
                    count += 1;
                }
                Err(err) => warn!("Error writing plugin {}: {}", p, err),
            }
        }
        info!("Updated morrowind.ini with {} plugins", count);
    } else {
        error!("Could not write cfg file {}", ini_path.display());
        return None;
    }

    Some(manifest.files.len())
}

/// Cleans up a directory with a valid omw-util.manifest file
pub fn cleanup(dir_option: &Option<PathBuf>) -> Option<usize> {
    // checks
    let mut in_path = &Path::new("./")
        .canonicalize()
        .expect("Could not expand relative path");
    if let Some(path) = dir_option {
        // checks
        if !path.exists() {
            error!("{} does not exist", path.display());
            return None;
        }
        if !path.is_dir() {
            error!("{} is not a directory", path.display());
            return None;
        }
        in_path = path;
    }

    // read manifest
    let manifest_path = in_path.join("omw-util.manifest");
    if manifest_path.exists() {
        if let Ok(file_content) = fs::read_to_string(&manifest_path) {
            if let Ok(manifest) = toml::from_str::<Manifest>(file_content.as_str()) {
                // read the files
                info!("Found {} files to delete", manifest.files.len());
                info!(
                    "Found {} existing files to ignore",
                    manifest.existing_files.len()
                );
                let mut count = 0;
                for file_name in &manifest.files {
                    // check against existing mod files
                    if manifest.existing_files.contains(file_name) {
                        debug!("Skipping existing file {}", file_name);
                        continue;
                    }
                    // delete file
                    let file = in_path.join(file_name);
                    if fs::remove_file(file).is_err() {
                        debug!("Could not delete file {}", file_name);
                    } else {
                        debug!("Deleted file {}", file_name);
                        count += 1;
                    }
                }
                if count != manifest.files.len() - manifest.existing_files.len() {
                    warn!("Not all files were deleted!")
                }

                info!("Removed {} files from {}", count, in_path.display());
                return Some(count);
            }
        }
        error!("Could not read manifest file {}", manifest_path.display());
    } else {
        error!("No manifest file at {}", manifest_path.display());
    }

    None
}

/// Imports all plugins in a folder to an openmw.cfg
/// # Caveats
/// This is meant to be used in conjunction with a proper mod manager!
/// It does not filter the plugins according to a morrowind.ini
///
/// # Panics
///
/// Panics if filenames are stupid
pub fn import(data_files_opt: Option<PathBuf>, cfg_opt: Option<PathBuf>, clean: bool) -> bool {
    // checks
    let mut data_files_path = Path::new("./")
        .canonicalize()
        .expect("Could not expand relative path");
    if let Some(path) = data_files_opt {
        // checks
        if !path.exists() {
            error!("{} does not exist", path.display());
            return false;
        }
        if !path.is_dir() {
            error!("{} is not a directory", path.display());
            return false;
        }
        data_files_path = path;
    }

    // find omw cfg
    let cfg_path = match check_cfg_path(cfg_opt) {
        Some(value) => value,
        None => return false,
    };

    // gets all plugins and sort them by modification time
    let mut all_plugins = get_plugins_in_folder(&data_files_path);
    // sort
    all_plugins.sort_by(|a, b| {
        fs::metadata(a)
            .expect("filetime")
            .modified()
            .unwrap()
            .cmp(&fs::metadata(b).expect("filetime").modified().unwrap())
    });
    info!("Found {} plugins to import", all_plugins.len());

    // get everything that is not a content line
    info!("Writing cfg {} ...", cfg_path.display());
    let mut original_cfg: Vec<String> = vec![];
    if let Ok(lines) = read_lines(&cfg_path) {
        for line in lines.flatten() {
            // parse each line
            if !line.starts_with("content=") {
                original_cfg.push(line);
            }
        }
    } else {
        error!("Could not parse cfg file {}", cfg_path.display());
        return false;
    }
    // reassemble cfg
    if let Ok(mut file) = File::create(&cfg_path) {
        // write original lines
        for line in original_cfg {
            // TODO proper eol
            let line_with_eol = format!("{}\n", line);
            match file.write(line_with_eol.as_bytes()) {
                Ok(_) => {}
                Err(err) => warn!("Error writing line {}: {}", line, err),
            }
        }
        // write plugins
        for p in all_plugins.iter() {
            // TODO proper eol
            let content_line = format!("content={}\n", p.file_name().unwrap().to_str().unwrap());
            match file.write(content_line.as_bytes()) {
                Ok(_) => {}
                Err(err) => warn!("Error writing plugin {}: {}", p.display(), err),
            }
        }

        info!("Imported {} plugins", all_plugins.len());
    } else {
        error!("Could not write cfg file {}", cfg_path.display());
        return false;
    }

    // optionally clean up
    if clean {
        info!("Cleaning up plugins ...");
        match cleanup(&Some(data_files_path)) {
            Some(_) => return true,
            None => return false,
        }
    }

    false
}
