import SwiftUI

// MARK: - Add Event View
struct AddEventView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var selectedTime: Date = Date()
    @State private var selectedColor: Color = .blue
    @State private var notes: String = ""
    @State private var isAllDay: Bool = false
    @State private var reminder: ReminderOption = .none
    
    private let colorOptions: [Color] = Color.eventColors
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 15)
            
            // Header
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("新增事件")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button("加入") {
                    addEvent()
                }
                .buttonStyle(.plain)
                .foregroundColor(title.isEmpty ? .secondary : .accentColor)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Title Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("標題")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("事件名稱", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    
                    // Date Display
                    VStack(alignment: .leading, spacing: 6) {
                        Text("日期")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.accentColor)
                            Text(viewModel.selectedDateString)
                                .font(.system(size: 14))
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.06))
                        )
                    }
                    
                    // All Day Toggle & Time
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $isAllDay) {
                            HStack {
                                Image(systemName: "sun.max")
                                    .foregroundColor(.orange)
                                Text("全天")
                                    .font(.system(size: 14))
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.accentColor)
                        
                        if !isAllDay {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.accentColor)
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("顏色")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(colorOptions, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                            .padding(2)
                                    )
                                    .shadow(color: color.opacity(selectedColor == color ? 0.5 : 0), radius: 4)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedColor = color
                                        }
                                    }
                            }
                        }
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 6) {
                        Text("提醒")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $reminder) {
                            ForEach(ReminderOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("備註")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(height: 60)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.06))
                            )
                            .scrollContentBackground(.hidden)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 360, height: 550)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
    }
    
    private func addEvent() {
        let event = CalendarEvent(
            title: title,
            date: viewModel.selectedDate,
            time: isAllDay ? nil : selectedTime,
            color: selectedColor,
            isAllDay: isAllDay,
            notes: notes.isEmpty ? nil : notes,
            reminder: reminder
        )
        viewModel.addEvent(event)
        isPresented = false
    }
}
