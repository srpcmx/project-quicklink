workspace "Project QuickLink" "A URL shortening service with a real-time analytics dashboard." {

    model {
        deploymentEnvironment "Production"

        // --- People ---
        user = person "User" "A person who wants to shorten a URL and share it."
        admin = person "Administrator" "A staff member who monitors the system, manages links, and views real-time analytics."

        // --- Software Systems ---
        quickLink = softwareSystem "Project QuickLink" "Allows users to create short, redirectable URLs and provides real-time analytics." {
            
            // --- Containers ---
            spa = container "Single-Page App" "The web interface for creating short links." "JavaScript, HTML"
            dashboardApp = container "Dashboard App" "A real-time dashboard for viewing analytics." "JavaScript, HTML"
            
            apiGateway = container "API Gateway" "Handles HTTP requests for creating links." "Amazon API Gateway"
            webSocketApi = container "WebSocket API" "Manages real-time WebSocket connections for the dashboard." "Amazon API Gateway"
            
            shorteningService = container "Shortening Service" "Handles creation of new short links." "Java, AWS Lambda"
            redirectService = container "Redirect Service" "Handles the lookup and redirection of a short link." "Java, AWS Lambda"
            analyticsService = container "Analytics Service" "Processes link access events to update analytics." "Java, AWS Lambda"
            dashboardService = container "Dashboard Service" "Pushes analytics updates to the dashboard via WebSockets." "Java, AWS Lambda" {
                // --- Components for Dashboard Service ---
                streamHandler = component "DynamoDB Stream Handler" "Receives and processes stream events from the analytics table." "Java, AWS Lambda Handler"
                webSocketPusher = component "WebSocket Pusher" "Pushes data to connected clients via the WebSocket API." "Java Component"
            }
            
            urlTable = container "URL Table" "Stores the mapping of short codes to original URLs." "Amazon DynamoDB" "Database"
            analyticsTable = container "Analytics Table" "Stores aggregated analytics data for links. Has a stream enabled." "Amazon DynamoDB" "Database"
            webSocketConnectionsTable = container "Connections Table" "Stores active WebSocket connection IDs." "Amazon DynamoDB" "Database"
            
            eventBus = container "Event Bus" "Receives events for asynchronous processing." "Amazon EventBridge"
        }

        // --- Relationships ---
        user -> spa "Uses"
        admin -> dashboardApp "Views real-time data on"
        
        spa -> apiGateway "Makes API calls" "JSON/HTTPS"
        dashboardApp -> webSocketApi "Connects to" "WSS"
        
        apiGateway -> shorteningService "Routes 'POST /links' to"
        apiGateway -> redirectService "Routes 'GET /{shortCode}' to"
        
        webSocketApi -> dashboardService "Routes connect/disconnect events to"
        
        shorteningService -> urlTable "Writes to"
        redirectService -> urlTable "Reads from"
        
        analyticsService -> analyticsTable "Updates"
        dashboardService -> analyticsTable "Reads from (via Stream)"
        dashboardService -> webSocketConnectionsTable "Manages connection IDs in"
        
        shorteningService -> eventBus "Publishes 'UrlCreatedEvent'"
        redirectService -> eventBus "Publishes 'UrlAccessedEvent'"
        eventBus -> analyticsService "Pushes events to"
        
        analyticsTable -> dashboardService "Triggers via DynamoDB Stream"
        dashboardService -> webSocketApi "Pushes updates to"
        webSocketApi -> dashboardApp "Pushes updates to"
        
        // Component relationships for Dashboard Service
        streamHandler -> webSocketPusher "Calls"
    }

    views {
        systemContext quickLink "SystemContext" {
            include *
            autoLayout
        }

        container quickLink "Containers" {
            include *
            autoLayout
        }

        component dashboardService "DashboardServiceComponents" {
            include *
            autoLayout
        }
        
        deployment quickLink "Production" "AWS" {
            deploymentNode "AWS" "" "Amazon Web Services" {
                deploymentNode "us-east-1" "" "AWS Region" {
                    deploymentNode "API Gateway (HTTP)" "" "Amazon API Gateway" {
                        containerInstance apiGateway
                    }
                    deploymentNode "API Gateway (WebSocket)" "" "Amazon API Gateway" {
                        containerInstance webSocketApi
                    }
                    deploymentNode "Lambda" "" "AWS Lambda" {
                        containerInstance shorteningService
                        containerInstance redirectService
                        containerInstance analyticsService
                        containerInstance dashboardService
                    }
                    deploymentNode "DynamoDB" "" "Amazon DynamoDB" {
                        containerInstance urlTable
                        containerInstance analyticsTable
                        containerInstance webSocketConnectionsTable
                    }
                    deploymentNode "EventBridge" "" "Amazon EventBridge" {
                        containerInstance eventBus
                    }
                    deploymentNode "S3" "" "Amazon S3" {
                        containerInstance spa
                        containerInstance dashboardApp
                    }
                }
            }
            autoLayout
        }

        styles {
            element "Person" { background #08427b; color #ffffff; shape Person }
            element "Software System" { background #1168bd; color #ffffff }
            element "Container" { background #438dd5; color #ffffff }
            element "Database" { shape Cylinder }
            element "Component" { background #85bbf0; color #000000 }
            element "Deployment Node" { background #232F3E; color #FFFFFF; shape WebBrowser }
        }
    }
}