import sys
from pyspark.sql import SparkSession
import socket

spark = SparkSession.builder.appName("SanityCheck").getOrCreate()

print(f"I am running on node: {socket.gethostname()}")

# Get output file name from command line argument
if len(sys.argv) < 3:
    print("Usage: spark-submit test.py <output_file_name> <data_file_name>")
    sys.exit(1)

output_name = sys.argv[1][1:]
data_file = sys.argv[2][1:]

try:
    df = spark.read.text(f"hdfs://spk-mst-01:9000/{data_file}")
    print(f"Read {df.count()} lines from HDFS.")
    df.write.mode("overwrite").text(f"hdfs://spk-mst-01:9000/{output_name}")

except Exception as e:
    print(f"HDFS Operation Failed: {e}")

spark.stop()
