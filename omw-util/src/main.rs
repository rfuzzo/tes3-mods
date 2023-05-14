use clap::{Parser, Subcommand};
use omw_util::export;
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
    /// Copy plugins found in the openmw.cfg to specified directory, default is current working directory
    Export {
        // arguments
        /// TBD
        out_dir: Option<PathBuf>,

        // options
        /// TBD
        #[arg(short, long)]
        in_dir: Option<PathBuf>,
    },
}

fn main() -> ExitCode {
    simple_logger::init().unwrap();
    let cli = Cli::parse();

    match &cli.command {
        Some(Commands::Export { in_dir, out_dir }) => {
            let _result = export(out_dir, in_dir);
            ExitCode::SUCCESS
        }
        None => ExitCode::FAILURE,
    }
}
