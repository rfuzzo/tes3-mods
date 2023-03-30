use clap::{Parser, Subcommand};
use mwscript::dump_scripts;
use std::path::PathBuf;

#[derive(Parser)]
#[command(author, version)]
#[command(about = "Tools for working with mwscripts", long_about = None)]
struct Cli {
    #[command(subcommand)]
    commands: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Dump scripts from a plugin.
    Dump {
        /// input path
        #[arg(short, long)]
        input: Option<PathBuf>,
    },
}

fn main() {
    let cli = Cli::parse();

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.commands {
        Commands::Dump { input } => match dump_scripts(input, None) {
            Ok(_) => println!("Done."),
            Err(err) => println!("Error dumping scripts: {}", err),
        },
    }
}
