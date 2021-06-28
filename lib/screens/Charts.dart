import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:trac2move/util/DataLoader.dart';
import 'dart:math';

class Charts extends StatefulWidget {
  const Charts({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _Charts createState() => _Charts();
}

class _Charts extends State<Charts> {

  Widget _buildTrackerBarChartSteps() {
    return FutureBuilder(
        future: getStepsCharts(),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          if (snapshot.hasData) {
            return SfCartesianChart(
                borderWidth: 0,
                plotAreaBorderWidth: 0,
                title: ChartTitle(
                    text: 'Tägliche Schritte',
                    textStyle: TextStyle(color: Colors.white)),
                primaryXAxis: CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(color: Colors.white),
                ),
                primaryYAxis: NumericAxis(
                    majorGridLines: MajorGridLines(width: 0),
                    title: AxisTitle(text: ''),
                    minimum: 0,
                    maximum: snapshot.data[1].toDouble(),
                    majorTickLines: MajorTickLines(size: 0),
                    labelStyle: TextStyle(color: Colors.white)),
                series: _getTrackerBarSeriesSteps(snapshot.data[0]),
                tooltipBehavior: TooltipBehavior(enable: true),
              );
          } else {
            return Container();
          }
        });
  }

  Widget _buildTrackerBarChartMinutes() {
    return FutureBuilder(
        future: getActiveMinutesCharts(),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          if (snapshot.hasData) {

             return SfCartesianChart(
                borderWidth: 0,
                plotAreaBorderWidth: 0,
                title: ChartTitle(
                    text: 'Aktive Minuten',
                    textStyle: TextStyle(color: Colors.white)),
                primaryXAxis: CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(color: Colors.white),
                ),
                primaryYAxis: NumericAxis(
                    majorGridLines: MajorGridLines(width: 0),
                    title: AxisTitle(text: ''),
                    minimum: 0,
                    maximum: snapshot.data[1].toDouble(),
                    majorTickLines: MajorTickLines(size: 0),
                    labelStyle: TextStyle(color: Colors.white)),
                series: _getTrackerBarSeriesMinutes(snapshot.data[0]),
                tooltipBehavior: TooltipBehavior(enable: true),
              );
          } else {
            return Container();
          }
        });
  }

  Widget _buildTrackerColumnChart() {
    return FutureBuilder(
        future: getActiveMinutesCharts(),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          if (snapshot.hasData) {
            return SfCartesianChart(
              borderWidth: 0,
              plotAreaBorderWidth: 0,
              title: ChartTitle(
                  text: 'Intensitätsebenen',
                  textStyle: TextStyle(color: Colors.white)),
              legend: Legend(
                  isVisible: true, textStyle: TextStyle(color: Colors.white)),
              primaryXAxis: CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(color: Colors.white)),
              primaryYAxis: NumericAxis(
                  minimum: 0, //snapshot.data[1].toDouble()
                  maximum: getChartsMaximum(snapshot.data),
                  axisLine: AxisLine(width: 0),
                  majorGridLines: MajorGridLines(width: 0),
                  majorTickLines: MajorTickLines(size: 0),
                  labelStyle: TextStyle(color: Colors.white)),
              series: _getTrackerColumnSeriesMinutes(snapshot.data),
              tooltipBehavior: TooltipBehavior(enable: true),
            );
          }
          else {
            return Container();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return new Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(195, 130, 89, 1),
        title: Text("Ihre tägliche Übersicht",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          Icon(
            Icons.track_changes_rounded,
            color: Colors.white,
            size: 50.0,
          )
        ],
        leading: new IconButton(
            icon: new Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
            }),
      ),
      body: Container(
        width: size.width,
        height: size.height,
        color: Color.fromRGBO(57, 70, 84, 1.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: size.width * 0.95,
                  height: size.height * 0.2,
                  color: Color.fromRGBO(57, 70, 84, 1.0),
                  child: _buildTrackerBarChartSteps(),
                ),
              ],
            ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   crossAxisAlignment: CrossAxisAlignment.center,
            //   children: [
            //     Container(
            //       width: size.width * 0.95,
            //       height: size.height * 0.2,
            //       color: Color.fromRGBO(57, 70, 84, 1.0),
            //       child: _buildTrackerBarChartMinutes(),
            //     ),
            //   ],
            // ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: size.width * 0.95,
                  height: size.height * 0.65,
                  color: Color.fromRGBO(57, 70, 84, 1.0),
                  child: _buildTrackerColumnChart(),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

List<BarSeries<ChartSampleData, String>>
    _getTrackerBarSeriesSteps(current_steps) {
  final List<ChartSampleData> chartData = <ChartSampleData>[
    ChartSampleData(x: 'Schritte', y: current_steps)
  ];
  return <BarSeries<ChartSampleData, String>>[
    BarSeries<ChartSampleData, String>(
      dataSource: chartData,
      borderRadius: BorderRadius.circular(15),
      trackColor: const Color.fromRGBO(198, 201, 207, 1),
      color: const Color.fromRGBO(89, 154, 195, 1),
      name: "Schritte",

      /// If we enable this property as true,
      /// then we can show the track of series.

      isTrackVisible: true,
      dataLabelSettings: DataLabelSettings(
          isVisible: true, labelAlignment: ChartDataLabelAlignment.top),
      xValueMapper: (ChartSampleData sales, _) => sales.x,
      yValueMapper: (ChartSampleData sales, _) => sales.y,
    ),
  ];
}

List<BarSeries<ChartSampleData, String>>
_getTrackerBarSeriesMinutes(current_minutes) {
  final List<ChartSampleData> chartData = <ChartSampleData>[
    ChartSampleData(x: 'Minuten', y: current_minutes)
  ];
  return <BarSeries<ChartSampleData, String>>[
    BarSeries<ChartSampleData, String>(
      dataSource: chartData,
      borderRadius: BorderRadius.circular(15),
      trackColor: const Color.fromRGBO(198, 201, 207, 1),
      color: const Color.fromRGBO(89, 154, 195, 1),
      name: "Minuten",

      /// If we enable this property as true,
      /// then we can show the track of series.

      isTrackVisible: true,
      dataLabelSettings: DataLabelSettings(
          isVisible: true, labelAlignment: ChartDataLabelAlignment.top),
      xValueMapper: (ChartSampleData sales, _) => sales.x,
      yValueMapper: (ChartSampleData sales, _) => sales.y,
    ),
  ];
}

List<ColumnSeries<ChartSampleData, String>> _getTrackerColumnSeriesMinutes(active_minutes) {
  final List<ChartSampleData> chartData = <ChartSampleData>[
    // ChartSampleData(x: 'Gesamt', y: active_minutes[0]),
    ChartSampleData(x: 'Niedrige Intensität', y: active_minutes[2]),
    ChartSampleData(x: 'Mittlere Intensität', y: active_minutes[3]),
    ChartSampleData(x: 'Hohe Intensität', y: active_minutes[4]),
  ];
  return <ColumnSeries<ChartSampleData, String>>[
    ColumnSeries<ChartSampleData, String>(
        dataSource: chartData,

        /// We can enable the track for column here.
        isTrackVisible: true,
        isVisibleInLegend: false,
        trackColor: const Color.fromRGBO(198, 201, 207, 1),
        borderRadius: BorderRadius.circular(15),
        xValueMapper: (ChartSampleData data, _) => data.x,
        yValueMapper: (ChartSampleData data, _) => data.y,
        name: 'Aktive Minuten',
        dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: const TextStyle(fontSize: 10, color: Colors.white)))
  ];
}

///Chart sample data
class ChartSampleData {
  /// Holds the datapoint values like x, y, etc.,
  ChartSampleData(
      {this.x,
      this.y,
      this.xValue,
      this.yValue,
      this.secondSeriesYValue,
      this.thirdSeriesYValue,
      this.pointColor,
      this.size,
      this.text,
      this.open,
      this.close,
      this.low,
      this.high,
      this.volume});

  /// Holds x value of the datapoint
  final dynamic x;

  /// Holds y value of the datapoint
  final num y;

  /// Holds x value of the datapoint
  final dynamic xValue;

  /// Holds y value of the datapoint
  final num yValue;

  /// Holds y value of the datapoint(for 2nd series)
  final num secondSeriesYValue;

  /// Holds y value of the datapoint(for 3nd series)
  final num thirdSeriesYValue;

  /// Holds point color of the datapoint
  final Color pointColor;

  /// Holds size of the datapoint
  final num size;

  /// Holds datalabel/text value mapper of the datapoint
  final String text;

  /// Holds open value of the datapoint
  final num open;

  /// Holds close value of the datapoint
  final num close;

  /// Holds low value of the datapoint
  final num low;

  /// Holds high value of the datapoint
  final num high;

  /// Holds open value of the datapoint
  final num volume;
}

double getChartsMaximum(List<int> data){
  data.removeWhere((value) => value == null);
  int maximum = 0;
  data.forEach((element) {
    if (element == null) {
      element = 0;
    }
    if (element > maximum) {
      maximum = element;
    }
  });
  return maximum.toDouble();
}
