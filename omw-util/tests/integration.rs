#[cfg(test)]
mod integration_tests {
    use std::{
        fs::{self, File},
        io::{self, BufRead},
        path::{Path, PathBuf},
    };

    fn get_cfg() -> &'static Path {
        return Path::new("tests/assets/openmw.cfg");
    }

    fn get_out_path() -> &'static Path {
        return Path::new("tests/assets/Data Files");
    }

    /// Returns an Iterator to the Reader of the lines of the file.
    pub fn read_lines<P>(filename: P) -> io::Result<io::Lines<io::BufReader<File>>>
    where
        P: AsRef<Path>,
    {
        let file = File::open(filename)?;
        Ok(io::BufReader::new(file).lines())
    }

    /// Parses the omwcfg and returns the data directories and content files
    fn parse_cfg(cfg_path: &Path) -> Option<(Vec<PathBuf>, Vec<String>)> {
        let mut data_dirs: Vec<PathBuf> = vec![];
        let mut plugin_names: Vec<String> = vec![];

        println!("Parsing cfg {} ...", cfg_path.display());
        // TODO logging
        if let Ok(lines) = read_lines(cfg_path) {
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
            None
        }
    }

    /// Create a manifest of files to copy
    ///
    /// # Panics
    ///
    /// Panics if the self value equals None of a file in the cfg
    fn create_manifest(data_dirs: Vec<PathBuf>, plugin_names: &[String]) -> Vec<PathBuf> {
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
                                    // TODO omw
                                    if ext == "esp" || ext == "omwaddon" || ext == "omwscripts" {
                                        // rust wtf :hidethepain:
                                        let file_name = file_path
                                            .file_name()
                                            .unwrap()
                                            .to_str()
                                            .unwrap()
                                            .to_owned();
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
                // TODO logging
            }
        }
        manifest
    }

    /// Copies the files specified in the manifest to out_path
    fn copy_files(manifest: &Vec<PathBuf>, out_path: &Path) -> Option<usize> {
        if !out_path.is_dir() {
            return None;
        }
        let mut count = 0;
        for file in manifest {
            // copy file
            if let Some(file_name) = file.file_name() {
                match fs::copy(file, out_path.join(file_name)) {
                    Ok(_) => {
                        println!("Copied {}", file.display()); // TODO logging
                        count += 1;
                    }
                    Err(_) => {
                        println!("Failed to copy {}", file.display()); // TODO logging
                    }
                }
            }
        }
        Some(count)
    }

    #[test]
    fn test_parse() {
        let in_path = get_cfg();
        assert!(in_path.exists());
        let out_path = get_out_path();
        assert!(out_path.exists());

        // parse cfg for data dirs
        let result = parse_cfg(in_path);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        println!("Found {} data dirs", data_dirs.len()); // TODO logging
        println!("Found {} plugins", plugin_names.len()); // TODO logging

        assert!(!data_dirs.is_empty());
        assert!(!plugin_names.is_empty());

        // create a manifest
        println!("Creating manifest ..."); // TODO logging
        let manifest = create_manifest(data_dirs, &plugin_names);
        // TODO when are all plugins accounted for?
        assert_eq!(manifest.len(), plugin_names.len());
        if manifest.len() == plugin_names.len() {
            println!("All plugins accounted for!"); // TODO logging
        } else {
            // TODO logging
        }

        // now copy the actual files
        println!("Copying files to {} ...", out_path.display()); // TODO logging
        let copy_result = copy_files(&manifest, out_path);
        assert!(copy_result.is_some());
        if let Some(count) = copy_result {
            println!("Copied {} files", count); // TODO logging
            assert_eq!(manifest.len(), count);
            if count == manifest.len() {
                println!("All files accounted for!"); // TODO logging
            }
        }

        // TODO cleanup
    }
}
