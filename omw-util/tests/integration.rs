#[cfg(test)]
mod integration_tests {
    use std::path::{Path, PathBuf};

    use omw_util::{cleanup, export};

    fn get_cfg() -> (PathBuf, usize, usize) {
        (Path::new("tests/assets/openmw.cfg").into(), 2, 2)
    }
    fn get_out_path() -> PathBuf {
        Path::new("tests/assets/Data Files").into()
    }

    #[test]
    fn test_export() {
        simple_logger::init().unwrap();
        let (p, _d, c) = get_cfg();
        let result = export(&Some(p), &Some(get_out_path()));
        assert_eq!(result, Some(c));

        let cleanup = cleanup(&Some(get_out_path()));
        assert_eq!(cleanup, Some(c));
    }
}
