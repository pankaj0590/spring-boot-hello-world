package com.springboot.aws.beanstalk;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.PropertySource;

@SpringBootApplication
@PropertySource("classpath:application-${spring.profiles.active}.yml")
@ComponentScan({"com.springboot"})
public class SpringBootAwsBeanstalkApplication {

	public static void main(String[] args) {
		SpringApplication.run(SpringBootAwsBeanstalkApplication.class, args);
	}

}
