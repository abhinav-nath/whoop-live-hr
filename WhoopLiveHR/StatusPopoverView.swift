import SwiftUI
import Charts
import AppKit


// MARK: - Main Popover

struct StatusPopoverView:
    View {

    @ObservedObject
    var heartRateMonitor: WhoopHeartRateMonitor


    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            header

            Divider()

            heartRateSection

            chartSection

            Divider()

            deviceSection

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 340)
    }


    // MARK: Header

    private var header: some View {

        HStack {

            Text("WHOOP Live HR")
            .font(.headline)


            Spacer()


            Circle()
                .fill(
                    heartRateMonitor.isConnected
                        ? Color.green
                        : Color.orange
                )
                .frame(
                    width: 8,
                    height: 8
                )


            Text(
                heartRateMonitor.isConnected
                    ? "Connected"
                    : "Disconnected"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: Heart Rate

    private var heartRateSection: some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: 7
        ) {

            Image(systemName: "heart.fill")
            .font(.system(size: 22))


            Text(
                heartRateMonitor
                    .heartRate
                    .map(String.init)
                    ?? "--"
            )
            .font(
                .system(
                    size: 40,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .monospacedDigit()


            Text("BPM")
                .font(.callout)
                .foregroundStyle(
                    .secondary
                )


            Spacer()
        }
    }


    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {

        if heartRateMonitor
            .history
            .count >= 2 {

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                HStack {

                    Text("Last 5 minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)


                    Spacer()


                    if let stats = statistics {

                        Text(
                            "Min \(stats.min)   Avg \(stats.avg)   Max \(stats.max)"
                        )
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    }
                }


                Chart(
                    heartRateMonitor.history
                ) { sample in

                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Heart Rate", sample.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis {

                    AxisMarks(
                        position: .leading
                    ) {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartYScale(
                    domain: chartYDomain
                )
                .frame(
                    height: 130
                )
            }

        } else {

            VStack(
                spacing: 8
            ) {

                ProgressView().controlSize(.small)


                Text(
                    heartRateMonitor
                        .isConnected
                        ? "Collecting heart-rate data..."
                        : heartRateMonitor.status
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
        }
    }


    // MARK: Device

    private var deviceSection: some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            HStack {

                Text(heartRateMonitor.deviceName)
                .font(.callout)


                Spacer()


                if let rssi = heartRateMonitor.rssi {

                    Text(signalDescription(rssi))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }


            Text(heartRateMonitor.status)
            .font(.caption)
            .foregroundStyle(.secondary)


            if let lastUpdatedAt = heartRateMonitor.lastUpdatedAt {

                Text(
                    "Last reading \(lastUpdatedAt.formatted(date: .omitted, time: .standard))"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }


    // MARK: Footer

    private var footer: some View {

        HStack {

            Spacer()


            Button(
                "Quit"
            ) {

                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }


    // MARK: Statistics

    private var statistics:
        (
            min: Int,
            avg: Int,
            max: Int
        )? {

        let values = heartRateMonitor
                .history
                .map(\.bpm)


        guard
            let minimum = values.min(),
            let maximum = values.max(), !values.isEmpty
        else {
            return nil
        }


        let average =
            Int(round(Double(values.reduce(0, +)) / Double(values.count)))


        return (
            minimum,
            average,
            maximum
        )
    }


    // MARK: Chart scale

    private var chartYDomain: ClosedRange<Int> {

        let values = heartRateMonitor
                .history
                .map(\.bpm)


        guard
            let minimum = values.min(),
            let maximum = values.max()
        else {
            return 50...120
        }


        let lower = max(30, minimum - 10)


        let upper = max(lower + 20, maximum + 10)


        return lower...upper
    }


    // MARK: Signal quality

    private func signalDescription(
        _ rssi: Int
    ) -> String {

        switch rssi {

        case -59...0:
            return "\(rssi) dBm • Excellent"

        case -69 ... -60:
            return "\(rssi) dBm • Good"

        case -79 ... -70:
            return "\(rssi) dBm • Fair"

        default:
            return "\(rssi) dBm • Weak"
        }
    }
}
