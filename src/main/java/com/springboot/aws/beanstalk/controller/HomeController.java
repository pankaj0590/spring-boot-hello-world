package com.springboot.aws.beanstalk.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@CrossOrigin(origins = {"*"}, maxAge = 3600)
@Controller
@RequestMapping("/aws/")
public class HomeController {

        @GetMapping(value = "/home")
        public ResponseEntity getMessage(){

            return new ResponseEntity("Hello World with jenkins and github webhook, aws ecs cluster ", HttpStatus.OK);

        }
}
