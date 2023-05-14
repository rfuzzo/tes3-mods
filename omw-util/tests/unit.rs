#[cfg(test)]
mod unit_tests {
    use std::path::{Path, PathBuf};

    use omw_util::{cleanup, copy_files, get_plugins, parse_cfg};

    fn get_cfg() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw.cfg").into(), 2, 2)
    }
    fn get_cfg_full() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw_full.cfg").into(), 806, 578)
    }
    fn get_out_path() -> PathBuf {
        Path::new("tests/assets/Data Files").into()
    }

    #[test]
    fn test_parse() {
        // parse cfg for data dirs
        let (mut in_path, mut d, mut c) = get_cfg();
        assert!(in_path.exists());
        let result = parse_cfg(in_path);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        assert_eq!(data_dirs.len(), d);
        assert_eq!(plugin_names.len(), c);

        // parse full cfg for data dirs
        (in_path, d, c) = get_cfg_full();
        assert!(in_path.exists());
        let result = parse_cfg(in_path);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        assert_eq!(data_dirs.len(), d);
        assert_eq!(plugin_names.len(), c);
    }

    #[test]
    fn test_manifest() {
        // parse cfg for data dirs
        let (in_path, d, c) = get_cfg();
        assert!(in_path.exists());
        let result = parse_cfg(in_path);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        assert_eq!(data_dirs.len(), d);
        assert_eq!(plugin_names.len(), c);
        // create a manifest
        let files = get_plugins(data_dirs, &plugin_names);
        assert_eq!(files.len(), plugin_names.len());
    }

    #[test]
    fn test_copy() {
        let (in_path, d, c) = get_cfg();
        assert!(in_path.exists());
        let out_path = get_out_path();
        assert!(out_path.exists());

        // parse cfg for data dirs
        let result = parse_cfg(in_path);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        assert_eq!(data_dirs.len(), d);
        assert_eq!(plugin_names.len(), c);

        // create a manifest
        let files = get_plugins(data_dirs, &plugin_names);
        assert_eq!(files.len(), plugin_names.len());

        // now copy the actual files
        let copy_result = copy_files(&files, out_path.as_path());
        assert!(copy_result.is_some());
        let count = copy_result.unwrap().len();
        assert_eq!(count, c);

        // cleanup
        let cleanup = cleanup(&Some(out_path));
        assert_eq!(cleanup, Some(c));
    }
}
