import sys
from pyspark.sql import SparkSession
import socket

spark = SparkSession.builder.appName("SanityCheck").getOrCreate()

print(f"I am running on node: {socket.gethostname()}")

# Get output file name from command line argument
if len(sys.argv) < 3:
    print("Usage: spark-submit test.py <output_path> <data_path>")
    sys.exit(1)

# Strip leading slash if present to avoid double slashes in HDFS paths
output_path = sys.argv[1].lstrip('/')
data_path = sys.argv[2].lstrip('/')

try:
    df = spark.read.text(f"hdfs:///{data_path}")
    print(f"Read {df.count()} lines from HDFS.")
    df.write.mode("overwrite").text(f"hdfs:///{output_path}")

except Exception as e:
    print(f"HDFS Operation Failed: {e}")

spark.stop()
