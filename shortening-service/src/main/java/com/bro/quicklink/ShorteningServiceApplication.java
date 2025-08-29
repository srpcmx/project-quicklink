package com.bro.quicklink;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages = {"com.bro.quicklink"})
public class ShorteningServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(ShorteningServiceApplication.class, args);
    }

}
