#[cfg(test)]
mod integration_tests {
    use std::path::{Path, PathBuf};

    use omw_util::{cleanup, export, import, parse_cfg};

    // path, data dirs, plugins
    fn get_cfg() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw.cfg").into(), 3, 5)
    }
    fn get_out_cfg() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw_out.cfg").into(), 2, 2)
    }
    fn get_data_files_path() -> PathBuf {
        Path::new("tests/assets/Data Files").into()
    }

    #[test]
    fn test_export() {
        //simple_logger::init().unwrap();
        let data_files = get_data_files_path();

        let (p, _d, c) = get_cfg();
        let result = export(Some(p), Some(data_files.to_owned()), false);
        assert_eq!(result, Some(c));

        // check order

        let cleanup = cleanup(&Some(data_files));
        assert_eq!(cleanup, Some(c));
    }

    #[test]
    fn test_import() {
        let data_files = get_data_files_path();

        let (p, _d, c) = get_cfg();
        // export to set up test
        let result = export(Some(p), Some(data_files.to_owned()), false);
        assert_eq!(result, Some(c));

        // modify a file to test import
        let modified_esp = Path::new("tests/assets/Data Files/mod1.esp");
        assert!(std::fs::write(modified_esp, b"test").is_ok());

        // import
        let (p_out, d_out, c_out) = get_out_cfg();
        let result = import(Some(data_files), Some(p_out.clone()), true);
        assert!(result);

        // check cfg
        let result = parse_cfg(p_out);
        assert!(result.is_some());
        let Some((data_dirs ,plugin_names)) = result else { return };
        assert_eq!(data_dirs.len(), d_out);
        assert_eq!(plugin_names.len(), c_out);
    }
}
