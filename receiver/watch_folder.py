import time
import os
import shutil
import logging

# Set up logging
logging.basicConfig(level=logging.DEBUG,
                   format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    logger.info("Starting receiver file watcher")
    
    shared_dir = '/shared'
    data_dir = '/app/data'
    os.makedirs(data_dir, exist_ok=True)
    
    logger.info(f"Watching shared directory: {shared_dir}")
    logger.info(f"Initial contents of shared dir: {os.listdir(shared_dir)}")
    
    processed_files = set()
    
    while True:
        try:
            # Check for new files in shared directory
            for filename in os.listdir(shared_dir):
                src_path = os.path.join(shared_dir, filename)
                if os.path.isfile(src_path) and src_path not in processed_files:
                    dest_path = os.path.join(data_dir, filename)
                    logger.info(f"Found new file in shared volume: {filename}")
                    
                    try:
                        shutil.copy2(src_path, dest_path)
                        logger.info(f"Successfully copied {filename} to data directory")
                        processed_files.add(src_path)
                    except Exception as e:
                        logger.error(f"Error copying file {filename}: {str(e)}")
            
            time.sleep(1)
            
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}")
            time.sleep(1)

if __name__ == "__main__":
    main()