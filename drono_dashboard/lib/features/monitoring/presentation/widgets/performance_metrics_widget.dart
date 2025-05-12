import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:collection';
import 'dart:math' as math;

class PerformanceMetricsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final Map<String, List<double>> historicalData;
  
  const PerformanceMetricsWidget({
    Key? key, 
    required this.devices,
    required this.historicalData,
  }) : super(key: key);

  @override
  State<PerformanceMetricsWidget> createState() => _PerformanceMetricsWidgetState();
}

class _PerformanceMetricsWidgetState extends State<PerformanceMetricsWidget> {
  final int maxDataPoints = 30; // Show 30 data points max in the chart
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real-time Performance Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetricCard(
                    title: 'CPU Usage',
                    value: _getCurrentMetricValue('cpu'),
                    icon: Icons.memory,
                    color: Colors.blue,
                    suffix: '%',
                    historicalData: widget.historicalData['cpu'] ?? [],
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    title: 'Memory Usage',
                    value: _getCurrentMetricValue('memory'),
                    icon: Icons.storage,
                    color: Colors.purple,
                    suffix: '%',
                    historicalData: widget.historicalData['memory'] ?? [],
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    title: 'Uptime',
                    value: _getCurrentMetricValue('uptime'),
                    icon: Icons.timelapse,
                    color: Colors.green,
                    suffix: 'h',
                    historicalData: widget.historicalData['uptime'] ?? [],
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    title: 'Temperature',
                    value: _getCurrentMetricValue('temperature'),
                    icon: Icons.thermostat,
                    color: _getTemperatureColor(_getCurrentMetricValue('temperature')),
                    suffix: '°C',
                    historicalData: widget.historicalData['temperature'] ?? [],
                  ),
                  const SizedBox(width: 16),
                  _buildMetricCard(
                    title: 'Network',
                    value: _getCurrentMetricValue('network'),
                    icon: Icons.network_check,
                    color: Colors.green,
                    suffix: 'KB/s',
                    historicalData: widget.historicalData['network'] ?? [],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    required String suffix,
    required List<double> historicalData,
  }) {
    // Format display value based on metric type
    String displayValue;
    if (title == 'Uptime') {
      int days = value ~/ 24; // Integer division for days
      double hours = value % 24; // Remainder for hours
      if (days > 0) {
        displayValue = '${days}d ${hours.toStringAsFixed(1)}h';
      } else {
        displayValue = '${hours.toStringAsFixed(1)}h';
      }
    } else {
      displayValue = '${value.toStringAsFixed(1)}$suffix';
    }
    
    return Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildLineChart(historicalData, color, title == 'Uptime'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<double> dataPoints, Color color, bool isUptime) {
    if (dataPoints.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Limit the number of data points to maxDataPoints
    final limitedDataPoints = dataPoints.length > maxDataPoints
        ? dataPoints.sublist(dataPoints.length - maxDataPoints)
        : dataPoints;

    // Find min and max values for better scaling
    double minY = limitedDataPoints.reduce(math.min);
    double maxY = limitedDataPoints.reduce(math.max);
    
    // Ensure there is at least some range for the chart
    if (maxY - minY < 5) {
      minY = maxY - 5 > 0 ? maxY - 5 : 0;
    }
    
    // For battery, force range to be 0-100
    if (!isUptime && (color == Colors.green || color == Colors.orange || color == Colors.red)) {
      minY = 0;
      maxY = 100;
    }
    
    // For uptime, set appropriate range
    if (isUptime) {
      minY = 0;
      // Adjust the max value to be a bit higher than the current max
      maxY = maxY * 1.2;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: (maxY - minY) / 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY - minY) / 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        minX: 0,
        maxX: limitedDataPoints.length.toDouble() - 1,
        minY: minY,
        maxY: maxY + ((maxY - minY) * 0.1), // Add 10% padding at the top
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.shade800,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              limitedDataPoints.length,
              (index) => FlSpot(index.toDouble(), limitedDataPoints[index]),
            ),
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  double _getCurrentMetricValue(String metric) {
    if (widget.devices.isEmpty) {
      // Default values if no devices
      switch (metric) {
        case 'cpu': return 0.0;
        case 'memory': return 0.0;
        case 'uptime': return 0.0;
        case 'temperature': return 0.0;
        case 'network': return 0.0;
        default: return 0.0;
      }
    }

    // Get the first device's metrics
    final device = widget.devices[0];
    
    switch (metric) {
      case 'cpu':
        return device['cpu_usage']?.toDouble() ?? 0.0;
      case 'memory':
        return device['memory_usage']?.toDouble() ?? 0.0;
      case 'uptime':
        return device['uptime']?.toDouble() ?? 0.0;
      case 'temperature':
        return device['temperature']?.toDouble() ?? 0.0;
      case 'network':
        return device['network_usage']?.toDouble() ?? 0.0;
      default:
        return 0.0;
    }
  }

  Color _getBatteryColor(double value) {
    if (value < 20) return Colors.red;
    if (value < 50) return Colors.orange;
    return Colors.green;
  }
  
  Color _getTemperatureColor(double value) {
    if (value > 45) return Colors.red;
    if (value > 35) return Colors.orange;
    return Colors.blue;
  }