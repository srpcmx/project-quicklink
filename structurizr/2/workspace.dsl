workspace "Project QuickLink" "A URL shortening service." {
    model {
        user = person "User" "A person who wants to shorten a URL and share it."
        admin = person "Administrator" "A staff member who monitors the system and manages links."

        quickLink = softwareSystem "Project QuickLink" "Allows users to create short, redirectable URLs and provides analytics." {

            spa = container "Single-Page App" "The web interface that the user interacts with." "JavaScript, React"
            dashboardApp = container "Dashboard App" "A real-time dashboard for viewing analytics." "JavaScript, HTML"

            apiGateway = container "API Gateway" "Routes API requests to the appropriate backend Lambda function." "Amazon API Gateway"
            webSocketApi = container "WebSocket API" "Manages real-time WebSocket connections for the dashboard." "Amazon API Gateway"

            shorteningService = container "Shortening Service" "Handles creation of new short links." "Java, AWS Lambda"
            redirectService = container "Redirect Service" "Handles the lookup and redirection of a short link." "Java, AWS Lambda"
            analyticsService = container "Analytics Service" "Processes link access events to gather analytics." "Java, AWS Lambda"
            dashboardService = container "Dashboard Service" "Pushes analytics updates to the dashboard via WebSockets." "Java, AWS Lambda" {
                // --- Components for Dashboard Service ---
                streamHandler = component "DynamoDB Stream Handler" "Receives and processes stream events from the analytics table." "Java, AWS Lambda Handler"
                webSocketPusher = component "WebSocket Pusher" "Pushes data to connected clients via the WebSocket API." "Java Component"
            }

            urlTable = container "URL Table" "Stores the mapping of short codes to original URLs." "Amazon DynamoDB" "Database"
            analyticsTable = container "Analytics Table" "Stores aggregated analytics data for links." "Amazon DynamoDB" "Database"
            webSocketConnectionsTable = container "Connections Table" "Stores active WebSocket connection IDs." "Amazon DynamoDB" "Database"
            
            eventBus = container "Event Bus" "Receives events from services and routes them to subscribers for asynchronous processing." "Amazon EventBridge"
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
        
        live = deploymentEnvironment "Production" {
            deploymentNode "Amazon Web Services" {
                tags "Amazon Web Services - Cloud"
                
                deploymentNode "US-East-1" {
                    tags "Amazon Web Services - Region"
                
                    deploymentNode  "API Gateway" {
                        tags "Amazon Web Services - API Gateway"
                        containerInstance apiGateway
                    }

                    deploymentNode "API Gateway (WebSocket)" "" "Amazon API Gateway" {
                        tags "Amazon Web Services - API Gateway"
                        containerInstance webSocketApi
                    }

                    deploymentNode "AWS Lambda" {
                        tags "Amazon Web Services - Lambda"
                        containerInstance shorteningService "" "Deployment Node"
                        containerInstance redirectService "" "Deployment Node"
                        containerInstance analyticsService "" "Deployment Node"
                        containerInstance dashboardService "" "Deployment Node"
                    }

                    deploymentNode "Amazon DynamoDB" {
                        tags "Amazon Web Services - DynamoDB"
                        containerInstance urlTable
                        containerInstance analyticsTable
                        containerInstance webSocketConnectionsTable
                    }

                    deploymentNode "Amazon EventBridge" {
                        tags "Amazon Web Services - EventBridge"
                        containerInstance eventBus "" "Event Bus"
                    }

                    deploymentNode "Amazon S3" {
                        tags "Amazon Web Services - Simple Storage Service S3"
                        containerInstance spa
                        containerInstance dashboardApp
                    }
                }
            }
        }
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
        
        deployment quickLink live {
            include *
            autoLayout
        }

        styles {
            element "Element" {
                shape RoundedBox
                //background #ffffff
                color #000000
            }

            element "Person" {
                shape Person
                background #08427b
                color #ffffff
            }
            //element "Software System" { background #1168bd; color #ffffff }
            //element "Container" { background #438dd5; color #ffffff }
            element "Database" {
                shape Cylinder
            }

            element "Event Bus" {
                shape Pipe
                //background #ffffff
                color #000000
            }

            element "Deployment Node" {
                shape WebBrowser
                #background #232F3E
                color #FFFFFF
            }
        }

        theme https://static.structurizr.com/themes/amazon-web-services-2020.04.30/theme.json
    }

}