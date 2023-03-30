use clap::{Parser, Subcommand};
use mwscript::{dump, ESerializedType};
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
        /// input path, may be a plugin or a folder
        input: Option<PathBuf>,

        /// output directory to dump scripts to, defaults to cwd
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Create folder with plugin name, only available if input is a file
        #[arg(short, long)]
        create: bool,

        /// Include specific records
        #[arg(short, long)]
        include: Vec<String>,

        /// Exclude specific records
        #[arg(short, long)]
        exclude: Vec<String>,

        /// The extension to serialize to, default is yaml
        #[arg(short, long, value_enum)]
        serialize: ESerializedType,
    },
}

fn main() {
    let cli = Cli::parse();

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.commands {
        Commands::Dump {
            input,
            output,
            create,
            include,
            exclude,
            serialize,
        } => match dump(input, output, *create, include, exclude, serialize) {
            Ok(_) => println!("Done."),
            Err(err) => println!("Error dumping scripts: {}", err),
        },
    }
}
