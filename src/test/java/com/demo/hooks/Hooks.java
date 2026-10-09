package com.demo.hooks;

import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;

import com.demo.utils.DriverFactory;
import com.demo.utils.ConfigReader;
import com.demo.utils.TestContext;

import io.cucumber.java.After;
import io.cucumber.java.AfterStep;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;

@SuppressWarnings("unused") // Cucumber invoca esta clase y sus hooks mediante reflexión.
public final class Hooks {

    private final TestContext testContext;

    public Hooks(TestContext testContext) {
        this.testContext = testContext;
    }

    @Before
    public void iniciarNavegador() {
        DriverFactory.initDriver();
        testContext.setDriver(DriverFactory.getDriver());
    }

    @AfterStep
    public void adjuntarEvidenciaSiFalla(Scenario scenario) {
        if (scenario.isFailed()) {
            byte[] captura = ((TakesScreenshot) testContext.getDriver()).getScreenshotAs(OutputType.BYTES);
            scenario.attach(
                    captura,
                    ConfigReader.getRequired("evidence.screenshot.media-type"),
                    ConfigReader.getRequired("evidence.screenshot.name-prefix") + " - " + scenario.getName());
        }
    }

    @After
    public void cerrarNavegador() {
        DriverFactory.quitDriver();
    }
}
