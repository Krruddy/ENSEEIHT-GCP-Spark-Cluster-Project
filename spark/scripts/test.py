from pyspark.sql import SparkSession
import socket

spark = SparkSession.builder.appName("SanityCheck").getOrCreate()

print(f"I am running on node: {socket.gethostname()}")

try:
    df = spark.read.text("hdfs://spk-mst-01:9000/input/lorem_ipsum.txt")
    print(f"Read {df.count()} lines from HDFS.")
except Exception as e:
    print(f"HDFS Read Failed: {e}")

spark.stop()