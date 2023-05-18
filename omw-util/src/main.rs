use clap::{Parser, Subcommand};
use omw_util::{cleanup, export, import};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Verbose output
    #[arg(short, long)]
    verbose: bool,

    // subcommands
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Copy plugins found in the openmw.cfg to specified directory
    Export {
        // arguments
        /// The directory where the plugins should be copied to, default is current working directory
        dir: Option<PathBuf>,

        // options
        /// The path to the openmw.cfg, default is openMWs's default location
        #[arg(short, long)]
        config: Option<PathBuf>,
    },
    /// Cleans up a directory with a valid omw-util.manifest file
    Cleanup {
        // arguments
        /// The directory to clean up, default is current working directory
        dir: Option<PathBuf>,
    },
    /// Imports a morrowind.ini file contents to openmw.cfg.
    /// Currently only supports content names
    Import {
        // arguments
        /// The Data Files directory, default is current working directory
        dir: Option<PathBuf>,

        // options
        /// The path to the openmw.cfg, default is openMWs's default location
        #[arg(short, long)]
        in_path: Option<PathBuf>,

        /// Clean up files after importing
        #[arg(short, long)]
        cleanup: bool,
    },
}

fn main() -> ExitCode {
    simple_logger::init().unwrap();
    let cli = Cli::parse();

    match &cli.command {
        Some(Commands::Export { config, dir }) => {
            let _result = export(dir.to_owned(), config.to_owned(), cli.verbose);
            ExitCode::SUCCESS
        }
        Some(Commands::Import {
            dir,
            in_path: config,
            cleanup,
        }) => {
            if import(dir.to_owned(), config.to_owned(), *cleanup) {
                ExitCode::SUCCESS
            } else {
                ExitCode::FAILURE
            }
        }
        Some(Commands::Cleanup { dir }) => match cleanup(dir) {
            Some(_) => ExitCode::SUCCESS,
            None => ExitCode::FAILURE,
        },
        None => ExitCode::FAILURE,
    }
}
