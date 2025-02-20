#!/usr/bin/env python
"""
scripts/python/ihs_messaging_prompt1.py

This script reads the system prompt and user input files, calls the OpenAI API to
generate messages based on the provided inputs, and saves the generated messages
to an output file. It includes robust error handling and configuration management.
"""

import argparse
import configparser
import os
import sys
import re
from openai import OpenAI

def load_configuration(config_file):
    """
    Load the OpenAI API key from the configuration file.
    
    Args:
        config_file (str): Path to the configuration file.
        
    Returns:
        str: OpenAI API key.
        
    Raises:
        FileNotFoundError: If the configuration file does not exist.
        KeyError: If the 'api_key' is missing in the config file.
    """
    if not os.path.exists(config_file):
        raise FileNotFoundError(f"Configuration file not found: {config_file}")
    config = configparser.ConfigParser()
    config.read(config_file)
    if 'openai' not in config or 'api_key' not in config['openai']:
        raise KeyError("Missing 'api_key' under the [openai] section in the configuration file.")
    return config['openai']['api_key']

def generate_messages(api_key, input_data, system_message_content):
    """
    Generate messages by calling the OpenAI API with the given inputs.
    
    Args:
        api_key (str): OpenAI API key.
        input_data (str): The user input message.
        system_message_content (str): The system prompt message.
        
    Returns:
        dict: A dictionary containing messages for each level (Neutral, Low, Medium, High).
    """
    # Set the OpenAI API key
    client = OpenAI(api_key=api_key)

    try:
        response = client.chat.completions.create(model="gpt-4o-2024-05-13",
        messages=[
            {"role": "system", "content": system_message_content},
            {"role": "user", "content": input_data}
        ],
        temperature=0.8,
        max_tokens=350,
        top_p=1.0,
        frequency_penalty=0.0,
        presence_penalty=0.0)
    except Exception as e:
        print("Error during OpenAI API call:", e, file=sys.stderr)
        sys.exit(1)

    try:
        message_content = response.choices[0].message.content.strip()
    except (AttributeError, IndexError) as e:
        print("Error parsing response from OpenAI API:", e, file=sys.stderr)
        sys.exit(1)

    lines = message_content.split('\n')
    results = {}
    unparsed_segments = []

    # Extract messages for each level using a regex pattern
    for level in ["Neutral", "Low", "Medium", "High"]:
        pattern = f"^\\s*[-\\*\\_]*\\s*{re.escape(level)}(?:\\s+Message)?[\\*\\_]*\\s*[:\\-\\*]\\s*"
        line_found = None
        for line in lines:
            if re.search(pattern, line, re.IGNORECASE):
                line_found = line
                break
        if line_found:
            # Remove the prefix and clean up the message text
            message = re.sub(pattern, '', line_found, flags=re.IGNORECASE).strip().strip('"')
            results[level] = message
        else:
            results[level] = "Not found"
            unparsed_segments.append(f"No '{level}' level found in response.")

    if any(result == "Not found" for result in results.values()):
        print("\n".join(unparsed_segments), file=sys.stderr)

    return results

def main():
    parser = argparse.ArgumentParser(description='Generate Messages Based on User Inputs')
    parser.add_argument('--input_file', required=True, type=argparse.FileType('r'),
                        help='Path to the user input file')
    parser.add_argument('--config_file', required=True,
                        help='Path to the configuration file containing the API key')
    parser.add_argument('--system_prompt', required=True, type=argparse.FileType('r'),
                        help='Path to the system prompt file')
    parser.add_argument('--output_dir', required=True,
                        help='Directory to save the output file')
    parser.add_argument('--output_prefix', required=True,
                        help='Prefix for the output file name')
    args = parser.parse_args()

    try:
        api_key = load_configuration(args.config_file)
    except Exception as e:
        print("Configuration Error:", e, file=sys.stderr)
        sys.exit(1)

    system_message_content = args.system_prompt.read()
    input_data = args.input_file.read().strip()

    results = generate_messages(api_key, input_data, system_message_content)

    output_file_name = f"{args.output_prefix}_message_results.txt"
    output_file_path = os.path.join(args.output_dir, output_file_name)

    os.makedirs(args.output_dir, exist_ok=True)
    try:
        with open(output_file_path, 'w', encoding='utf-8') as file:
            # Write header
            file.write("Level\tMessage\n")
            # Write each message level and content
            for level in ["Neutral", "Low", "Medium", "High"]:
                file.write(f"{level}\t{results.get(level, 'Not found')}\n")
    except Exception as e:
        print("Error writing output file:", e, file=sys.stderr)
        sys.exit(1)

    print(f"Results have been saved to {output_file_path}")

if __name__ == '__main__':
    main()
