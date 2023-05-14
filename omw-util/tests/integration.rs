#[cfg(test)]
mod integration_tests {
    use std::path::{Path, PathBuf};

    use omw_util::{cleanup, export, import, parse_cfg};

    fn get_cfg() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw.cfg").into(), 2, 2)
    }
    fn get_out_cfg() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw_out.cfg").into(), 2, 2)
    }
    fn get_data_files_path() -> PathBuf {
        Path::new("tests/assets/Data Files").into()
    }

    #[test]
    fn test_export() {
        simple_logger::init().unwrap();
        let (p, _d, c) = get_cfg();
        let result = export(&Some(p), &Some(get_data_files_path()));
        assert_eq!(result, Some(c));

        let cleanup = cleanup(&Some(get_data_files_path()));
        assert_eq!(cleanup, Some(c));
    }

    #[test]
    fn test_import() {
        simple_logger::init().unwrap();
        let (p, _d, c) = get_cfg();
        // export to set up test
        let result = export(&Some(p), &Some(get_data_files_path()));
        assert_eq!(result, Some(c));
        // import
        let (p_out, d_out, c_out) = get_out_cfg();
        let result = import(&Some(get_data_files_path()), &Some(p_out.clone()), true);
        assert!(result);

        // check cfg
        let result = parse_cfg(p_out);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        assert_eq!(data_dirs.len(), d_out);
        assert_eq!(plugin_names.len(), c_out);
    }
}
