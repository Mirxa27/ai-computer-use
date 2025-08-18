import SwiftUI

struct ContextEditorView: View {
    @EnvironmentObject var aiManager: AIManager
    @State private var contextParameters: [ContextParameter] = []
    @State private var selectedParameter: ContextParameter?
    @State private var showAddParameter = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Context Parameters")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Content
            HSplitView {
                // Parameters list
                VStack(alignment: .leading, spacing: 0) {
                    // Toolbar
                    HStack {
                        Text("Parameters")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showAddParameter = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    List(selection: $selectedParameter) {
                        ForEach($contextParameters) { $parameter in
                            ParameterRowView(parameter: $parameter)
                                .tag(parameter)
                        }
                        .onDelete(perform: deleteParameters)
                    }
                }
                .frame(minWidth: 250)
                
                // Parameter editor
                if let parameter = selectedParameter {
                    ParameterEditorView(parameter: binding(for: parameter))
                } else {
                    EmptyParameterView()
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(contextParameters.filter { $0.isActive }.count) active parameters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Save") {
                    saveParameters()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 800, height: 600)
        .sheet(isPresented: $showAddParameter) {
            AddParameterView { parameter in
                contextParameters.append(parameter)
                selectedParameter = parameter
            }
        }
        .onAppear {
            loadParameters()
        }
    }
    
    private func binding(for parameter: ContextParameter) -> Binding<ContextParameter> {
        guard let index = contextParameters.firstIndex(where: { $0.id == parameter.id }) else {
            return .constant(parameter)
        }
        return $contextParameters[index]
    }
    
    private func loadParameters() {
        contextParameters = aiManager.getContextParameters()
    }
    
    private func saveParameters() {
        for parameter in contextParameters {
            aiManager.updateContextParameter(parameter)
        }
    }
    
    private func deleteParameters(at offsets: IndexSet) {
        for index in offsets {
            let parameter = contextParameters[index]
            aiManager.removeContextParameter(parameter.id)
        }
        contextParameters.remove(atOffsets: offsets)
    }
}

// MARK: - Parameter Row View
struct ParameterRowView: View {
    @Binding var parameter: ContextParameter
    
    var body: some View {
        HStack {
            Toggle("", isOn: $parameter.isActive)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(parameter.name)
                    .font(.system(.body, design: .rounded))
                
                HStack(spacing: 4) {
                    Image(systemName: typeIcon)
                        .font(.caption2)
                    
                    Text(parameter.type.rawValue)
                        .font(.caption)
                    
                    if parameter.priority > 0 {
                        Text("• Priority: \(parameter.priority)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var typeIcon: String {
        switch parameter.type {
        case .systemBehavior:
            return "cpu"
        case .domainKnowledge:
            return "book"
        case .responseStyle:
            return "text.bubble"
        case .memoryContext:
            return "memorychip"
        case .taskSpecific:
            return "checklist"
        case .userPreference:
            return "person"
        }
    }
}

// MARK: - Parameter Editor View
struct ParameterEditorView: View {
    @Binding var parameter: ContextParameter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Edit Parameter")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Active", isOn: $parameter.isActive)
                    .toggleStyle(.switch)
            }
            .padding()
            
            Divider()
            
            Form {
                TextField("Name:", text: $parameter.name)
                
                Picker("Type:", selection: $parameter.type) {
                    ForEach(ContextParameter.ParameterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Value:")
                    TextEditor(text: $parameter.value)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                }
                
                Stepper("Priority: \(parameter.priority)",
                       value: $parameter.priority,
                       in: 0...10)
            }
            .padding()
            
            Spacer()
        }
    }
}

// MARK: - Empty Parameter View
struct EmptyParameterView: View {
    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select a parameter to edit")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Context parameters help customize AI behavior")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
            
            Spacer()
        }
    }
}

// MARK: - Add Parameter View
struct AddParameterView: View {
    let onAdd: (ContextParameter) -> Void
    
    @State private var name = ""
    @State private var value = ""
    @State private var type: ContextParameter.ParameterType = .systemBehavior
    @State private var priority = 5
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Context Parameter")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                TextField("Name:", text: $name)
                
                Picker("Type:", selection: $type) {
                    ForEach(ContextParameter.ParameterType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Value:")
                    TextEditor(text: $value)
                        .frame(minHeight: 100)
                }
                
                Stepper("Priority: \(priority)", value: $priority, in: 0...10)
                
                // Suggestions based on type
                if !suggestedValues.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestedValues, id: \.self) { suggestion in
                            Button(action: { value = suggestion }) {
                                Text(suggestion)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Add") {
                    let parameter = ContextParameter(
                        name: name,
                        value: value,
                        type: type,
                        priority: priority
                    )
                    onAdd(parameter)
                    dismiss()
                }
                .disabled(name.isEmpty || value.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
    
    private var suggestedValues: [String] {
        switch type {
        case .systemBehavior:
            return [
                "You are a helpful assistant with expertise in programming and technology.",
                "Maintain a professional and friendly tone in all interactions.",
                "Provide detailed explanations when asked technical questions."
            ]
        case .domainKnowledge:
            return [
                "You have deep knowledge in software development, particularly in Swift and macOS development.",
                "You are familiar with AI/ML concepts and best practices.",
                "You understand voice interface design principles."
            ]
        case .responseStyle:
            return [
                "Keep responses concise and to the point.",
                "Use bullet points and structured formatting when appropriate.",
                "Optimize responses for voice output - avoid complex formatting."
            ]
        case .memoryContext:
            return [
                "Remember user preferences mentioned in previous conversations.",
                "Maintain context across multiple interactions.",
                "Reference previous discussions when relevant."
            ]
        case .taskSpecific:
            return [
                "Focus on code generation and technical problem-solving.",
                "Prioritize practical solutions over theoretical discussions.",
                "Provide working code examples when possible."
            ]
        case .userPreference:
            return [
                "Prefer Swift and SwiftUI for code examples.",
                "Use modern async/await patterns in code.",
                "Include error handling in all code examples."
            ]
        }
    }
}