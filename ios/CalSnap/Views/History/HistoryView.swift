import Charts
import SwiftUI

struct HistoryView: View {
    @Environment(MealStore.self) private var meals

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let weekly = meals.weekly {
                        chart(weekly)
                        weekSummary(weekly)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("History")
            .task { await meals.loadWeekly() }
            .refreshable { await meals.loadWeekly() }
        }
    }

    private func chart(_ weekly: WeeklyStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 7 days").font(.headline)
            Chart {
                ForEach(weekly.days) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Calories", day.calories)
                    )
                    .foregroundStyle(day.calories > weekly.goal ? Color.orange : Color.accentColor)
                    .cornerRadius(6)
                }
                RuleMark(y: .value("Goal", weekly.goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(weekly.goal)").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 240)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func weekSummary(_ weekly: WeeklyStats) -> some View {
        let total = weekly.days.reduce(0) { $0 + $1.calories }
        let logged = weekly.days.filter { $0.calories > 0 }.count
        let avg = logged > 0 ? total / logged : 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Summary").font(.headline)
            HStack {
                stat("Daily avg", "\(avg)")
                stat("Days logged", "\(logged)/7")
                stat("Week total", "\(total)")
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
