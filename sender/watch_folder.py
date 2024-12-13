import time
import os
import shutil
import logging

# Set up logging
logging.basicConfig(level=logging.DEBUG,
                   format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def validate_file(file_path):
    try:
        logger.debug(f"Validating file: {file_path}")
        
        # Check if file exists
        if not os.path.exists(file_path):
            logger.error(f"File does not exist: {file_path}")
            return False

        # Check if file is not empty
        if os.path.getsize(file_path) == 0:
            logger.error(f"File {file_path} is empty - validation failed")
            return False
            
        logger.info(f"File {file_path} passed validation")
        return True
        
    except Exception as e:
        logger.error(f"Validation error for {file_path}: {str(e)}")
        return False

def process_file(src_path, processed_files):
    if src_path in processed_files:
        return
        
    filename = os.path.basename(src_path)
    dest_path = os.path.join('/shared', filename)
    
    logger.info(f"Processing file: {src_path}")
    logger.info(f"Destination path: {dest_path}")
    
    # Validate file before sending
    if validate_file(src_path):
        try:
            # Copy file to shared volume
            shutil.copy2(src_path, dest_path)
            logger.info(f"Successfully copied {filename} to shared volume")
            processed_files.add(src_path)
        except Exception as e:
            logger.error(f"Error copying file: {str(e)}")
    else:
        logger.warning(f"Skipped {filename} - failed validation")

def main():
    logger.info("Starting sender file watcher")
    
    data_dir = '/app/data'
    os.makedirs(data_dir, exist_ok=True)
    
    logger.info(f"Watching directory: {data_dir}")
    logger.info(f"Initial contents of {data_dir}: {os.listdir(data_dir)}")
    
    processed_files = set()
    
    while True:
        try:
            # Check for new files
            current_files = set()
            for filename in os.listdir(data_dir):
                filepath = os.path.join(data_dir, filename)
                if os.path.isfile(filepath):
                    current_files.add(filepath)
                    if filepath not in processed_files:
                        logger.info(f"Found new file: {filepath}")
                        process_file(filepath, processed_files)
            
            # Clean up processed files list
            processed_files = processed_files.intersection(current_files)
            
            time.sleep(1)
            
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}")
            time.sleep(1)

if __name__ == "__main__":
    main()