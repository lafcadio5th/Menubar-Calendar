import SwiftUI
import EventKit

struct EventDetailView: View {
    let event: CalendarEvent
    var onClose: () -> Void
    var onDelete: () -> Void // Callback for deletion
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(event.isAllDay ? "全天事件" : "事件詳情")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Title & Time
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.color)
                                .frame(width: 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(formatEventTime())
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Details List
                    VStack(spacing: 16) {
                        // Location
                        if let location = event.location, !location.isEmpty {
                            DetailRow(icon: "mappin.and.ellipse", text: location)
                        }
                        
                        // Calendar Name (We need to look this up, but for now we might skip or just show color)
                        // Note: CalendarEvent doesn't store calendar name directly yet, but we have ID.
                        // Ideally we'd look it up from ViewModel, but let's keep it simple.
                        
                        // URL
                        if let url = event.url {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "link")
                                    .frame(width: 20)
                                    .foregroundColor(.secondary)
                                Link(url.absoluteString, destination: url)
                                    .font(.system(size: 13))
                                Spacer()
                            }
                        }
                        
                        // Notes
                        if let notes = event.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "text.alignleft")
                                        .frame(width: 20)
                                        .foregroundColor(.secondary)
                                    Text("備註")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                Text(notes)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .padding(.leading, 32)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    private func formatEventTime() -> String {
        let dateDateFormatter = DateFormatter()
        dateDateFormatter.dateFormat = "M月d日 EEEE"
        let dateString = dateDateFormatter.string(from: event.date)
        
        if event.isAllDay {
            return "\(dateString) • 全天"
        } else {
            return "\(dateString) • \(event.timeString)"
        }
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
