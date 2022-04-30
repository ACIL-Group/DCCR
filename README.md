# DCCR

Deep Clustering Context Recognition (DCCR); materials for the upcoming ICML paper "Lifelong Context Recognition via Online Deep Clustering."

[issues-url]: https://github.com/AP6YC/DCCR/issues

## Table of Contents

- [DCCR](#dccr)
  - [Table of Contents](#table-of-contents)
  - [Usage](#usage)
  - [File Structure](#file-structure)
  - [Contributing](#contributing)
  - [History](#history)
  - [Credits](#credits)
    - [Authors](#authors)

## Usage

TODO

## File Structure

```
DCCR
├── dockerfiles             // Dockerfiles: for deployment
├── src                     // Source: julia scripts and modules
│   ├── experiments         //      Experiment scripts
│   ├── lib                 //      Common experimental code
│   └── utils               //      Utility scripts (data inspection, etc.)
├── opts                    // Options: files for each experiment, learner, etc.
├── test                    // Test: Pytest unit, integration, and environment tests
├── work                    // Work: Temporary file location (weights, datasets)
│   ├── data                //      Datasets
│   ├── models              //      Model weights
│   └── results             //      Generated results
├── .gitattributes          // Git: definitions for LFS patterns
├── .gitignore              // Git: .gitignore for the whole project
├── LICENSE                 // Git: license for the project
├── Project.toml            // Julia: project dependencies
└── README.md               // Doc: this document
```

## Contributing

Please raise an [issue][issues-url].

## History

- 6/25/2021 - Initialize the project.
- 4/6/2022 - Create anonymous submission release.

## Credits

### Authors

- Sasha Petrenko <sap625@mst.edu>
- Andrew Brna <andrew.brna@teledyne.com>
