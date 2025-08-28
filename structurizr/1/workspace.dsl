workspace {

    model {
        u = person "User"
        s = softwareSystem "Software System" {
            r24 = container "Transact R24" "" "Docker container"
            database = container "Database" "" "Relational database schema"
        }

        u -> r24 "Uses"
        r24 -> database "Reads from and writes to"
        
        live = deploymentEnvironment "Live" {
            deploymentNode "Amazon Web Services" {
                tags "Amazon Web Services - Cloud"
                
                deploymentNode "US-East-1" {
                    tags "Amazon Web Services - Region"
                
                    route53 = infrastructureNode "Route 53" {
                        tags "Amazon Web Services - Route 53"
                    }
                    apiGateway = infrastructureNode "API Gateway" {
                        tags "Amazon Web Services - API Gateway"
                    }

                    deploymentNode "Amazon EC2" {
                        tags "Amazon Web Services - EC2"
                        
                        deploymentNode "Amazon Linux" {
                            transactR24 = containerInstance r24
                        }
                    }

                    deploymentNode "Amazon RDS" {
                        tags "Amazon Web Services - RDS"
                        
                        deploymentNode "PostgreSQL" {
                            tags "Amazon Web Services - RDS PostgreSQL instance"
                            
                            containerInstance database
                        }
                    }
                }
            }
            
            route53 -> apiGateway "Forwards requests to" "HTTPS"
            apiGateway -> transactR24 "Forwards requests to" "HTTPS"
        }
    }

    views {
        deployment s live {
            include *
            autoLayout lr
        }

        styles {
            element "Element" {
                shape RoundedBox
                background #ffffff
                color #000000
            }
        }

        theme https://static.structurizr.com/themes/amazon-web-services-2020.04.30/theme.json
    }
    
}
