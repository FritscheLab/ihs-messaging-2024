# IHS Intervention Messages

## Description
The **IHS Intervention Messages** repository provides a comprehensive toolkit for generating customized intervention messages for the Intern Health Study (IHS). Using a combination of R and Python scripts, the project builds dynamic prompts from various text components and calls the OpenAI API to generate tailored messages. Key features include:
- Modular prompt generation using R scripts.
- Command-line integration with a Python script for API-based message generation.
- Extensive use of `data.table` for fast, memory-efficient data processing.
- Cross-platform compatibility and robust error handling.

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/ihs-messaging-2024/ihs-messaging-2024.git
cd ihs-messaging-2024
```

### 2. Set Up R Environment
- Ensure you have R (version ≥ 3.6.0) installed.
- Install required R packages. Open an R session and run:
```r
install.packages(c("data.table", "openxlsx"))
```
- The R scripts are located in `scripts/R`.

### 3. Set Up Python Environment
- Ensure you have Python (version ≥ 3.7) installed.
- Create and activate a virtual environment:
```bash
python -m venv venv
# On Linux/Mac:
source venv/bin/activate
# On Windows:
venv\Scripts\activate
```
- Install required Python packages:
```bash
pip install -r requirements.txt
```
- The Python scripts are located in `scripts/python`.

### 4. Configuration
Before running the scripts, create a `.config.ini` file in the root directory with your OpenAI API key. The file should have the following format:

```ini
[openai]
api_key = YOUR_API_KEY_HERE
```

Replace `YOUR_API_KEY_HERE` with your actual OpenAI API key. This configuration file is used by the Python scripts to authenticate API calls.

## Requirements
- **R**: Version ≥ 3.6.0 with packages: `data.table`, `openxlsx`
- **Python**: Version ≥ 3.7 with packages: `openai`, `argparse`, etc. (see `requirements.txt`)
- **Other**: Git, a Unix-like shell (or equivalent commands on Windows)

## Usage

### R Scripts Workflow
The project uses a series of R scripts to generate and combine prompt components, and finally format the output:

1. **Setup Environment**
   ```bash
   Rscript scripts/R/00_setup.R
   ```
2. **Generate Prompt Components**
   ```bash
   Rscript scripts/R/01_generate_prompts.R
   ```
3. **Run the Command Lines**
   ```bash
   results/command_lines.sh
   ```
4. **Format and Export the Output**
   ```bash
   Rscript scripts/R/02_format_output.R
   ```

### Python Script for Individual Message Generation
You can use the Python script to call the OpenAI API and generate messages:
```bash
python scripts/python/ihs_message_generation.py --input_file results/your_user_request.txt --config_file .config.ini --system_prompt results/your_prompt.txt --output_dir results --output_prefix your_prefix
```
*Replace `your_user_request.txt`, `your_prompt.txt`, and `your_prefix` with the appropriate file names and prefix.*

## Project Structure
```
ihs-messaging-2024/
├── .config.ini               # Configuration file containing your OpenAI API key
├── data
│   └── prompt_elements       # Static text files and prompt components
├── results                   # Generated prompts, messages, and output files
├── scripts
│   ├── python                # Python scripts (API calls and message generation)
│   └── R                     # R scripts (prompt generation, combination, and formatting)
├── README.md                 # This file
└── requirements.txt          # Python dependencies
```

## Contributing
Contributions are welcome! Please follow these guidelines:
- **Fork** the repository and create a new branch for your feature or bugfix.
- **Code Style:** Adhere to existing coding conventions and structure your commits clearly.
- **Testing:** Ensure your changes are well-tested and do not break existing functionality.
- **Pull Request:** Submit a pull request with a detailed description of your changes and any relevant issues.

## License
This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

## Contact
For issues, questions, or suggestions, please submit a GitHub issue.

## Additional Notes
- **Roadmap:** Future updates may include enhanced prompt customizations, expanded data handling, and improved API error handling.
- **Acknowledgments:** Special thanks to the IHS team for inspiring this project and to the open-source community for the invaluable tools and libraries.
