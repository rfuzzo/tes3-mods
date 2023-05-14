#[cfg(test)]
mod integration_tests {
    use std::path::{Path, PathBuf};

    use omw_util::export;

    fn get_cfg() -> PathBuf {
        Path::new("tests/assets/openmw.cfg").into()
    }
    fn get_out_path() -> PathBuf {
        Path::new("tests/assets/Data Files").into()
    }

    #[test]
    fn test_export() {
        simple_logger::init().unwrap();
        let result = export(&Some(get_cfg()), &Some(get_out_path()));
        assert_eq!(result, Some(2));
    }
}
