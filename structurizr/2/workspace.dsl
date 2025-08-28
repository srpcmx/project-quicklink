workspace "Project QuickLink" "A URL shortening service." {
    model {
        user = person "User" "A person who wants to shorten a URL and share it."
        admin = person "Administrator" "A staff member who monitors the system and manages links."

        quickLink = softwareSystem "Project QuickLink" "Allows users to create short, redirectable URLs and provides analytics." {

            spa = container "Single-Page App" "The web interface that the user interacts with." "JavaScript, React"
            apiGateway = container "API Gateway" "Routes API requests to the appropriate backend Lambda function." "Amazon API Gateway"

            shorteningService = container "Shortening Service" "Handles creation of new short links." "Java, AWS Lambda"
            redirectService = container "Redirect Service" "Handles the lookup and redirection of a short link." "Java, AWS Lambda"
            analyticsService = container "Analytics Service" "Processes link access events to gather analytics." "Java, AWS Lambda"

            urlTable = container "URL Table" "Stores the mapping of short codes to original URLs." "Amazon DynamoDB" "Database"
            analyticsTable = container "Analytics Table" "Stores aggregated analytics data for links." "Amazon DynamoDB" "Database"
            
            eventBus = container "Event Bus" "Receives events from services and routes them to subscribers for asynchronous processing." "Amazon EventBridge"
        }

        user -> spa "Uses" "HTTPS"
        admin -> spa "Uses" "HTTPS"

        spa -> apiGateway "Makes API calls" "JSON/HTTPS"

        apiGateway -> shorteningService "Routes 'POST /links' to"
        apiGateway -> redirectService "Routes 'GET /{shortCode}' to"
        apiGateway -> analyticsService "Routes 'GET /links/{shortCode}/analytics' to"

        redirectService -> urlTable "Reads link mapping from" "AWS SDK"
        analyticsService -> analyticsTable "Reads/Writes analytics data" "AWS SDK"

        redirectService -> eventBus "Publishes 'UrlAccessedEvent'" "AWS SDK"
        shorteningService -> eventBus "Publishes 'UrlCreatedEvent'" "AWS SDK"
        eventBus -> analyticsService "Pushes events to"
        
        live = deploymentEnvironment "Production" {
            deploymentNode "Amazon Web Services" {
                tags "Amazon Web Services - Cloud"
                
                deploymentNode "US-East-1" {
                    tags "Amazon Web Services - Region"
                
                    deploymentNode  "API Gateway" {
                        tags "Amazon Web Services - API Gateway"
                        containerInstance apiGateway
                    }

                    deploymentNode "AWS Lambda" {
                        tags "Amazon Web Services - Lambda"
                        containerInstance shorteningService "" "Deployment Node"
                        containerInstance redirectService "" "Deployment Node"
                        containerInstance analyticsService "" "Deployment Node"
                    }

                    deploymentNode "Amazon DynamoDB" {
                        tags "Amazon Web Services - DynamoDB"
                        containerInstance urlTable
                        containerInstance analyticsTable
                    }

                    deploymentNode "Amazon EventBridge" {
                        tags "Amazon Web Services - EventBridge"
                        containerInstance eventBus
                    }

                    deploymentNode "Amazon S3" {
                        tags "Amazon Web Services - Simple Storage Service S3"
                        containerInstance spa
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
            element "Deployment Node" {
                shape WebBrowser
                background #232F3E
                color #FFFFFF
            }
        }

        theme https://static.structurizr.com/themes/amazon-web-services-2020.04.30/theme.json
    }

}