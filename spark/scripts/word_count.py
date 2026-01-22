import sys
import time
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, split, col

def main():
    """
    Main function to execute the Word Count Spark job.
    """
    # Check for correct usage
    if len(sys.argv) < 3:
        print("Usage: spark-submit word_count.py <output_path> <data_path>", file=sys.stderr)
        sys.exit(1)

    # Parse arguments
    # Strip leading slash if present to avoid double slashes in HDFS paths
    output_path = sys.argv[1].lstrip('/')
    data_path = sys.argv[2].lstrip('/')

    # Initialize Spark Session
    spark = SparkSession.builder \
        .appName("WordCount") \
        .getOrCreate()

    start_time = time.time()

    try:
        # Read input data
        # Assuming the input is a text file or directory of text files
        input_uri = f"hdfs:///{data_path}"
        lines = spark.read.text(input_uri)

        # Perform Word Count
        # 1. Split lines into words using whitespace as a delimiter
        # 2. Explode the array of words into separate rows
        words = lines.select(
            explode(
                split(col("value"), "\\s+")
            ).alias("word")
        )

        # 3. Filter out empty strings (result of multiple spaces)
        words = words.filter(col("word") != "")

        # 4. Group by word and count
        word_counts = words.groupBy("word").count()

        # Write output
        output_uri = f"hdfs:///{output_path}"
        
        # Using CSV format to write (word, count) pairs
        word_counts.write.mode("overwrite").csv(output_uri)
        
        print(f"Successfully counted words from {input_uri} and saved to {output_uri}")

    except Exception as e:
        print(f"Error during Spark execution: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        end_time = time.time()
        print(f"Execution time: {end_time - start_time:.2f} seconds")
        spark.stop()

if __name__ == "__main__":
    main()
