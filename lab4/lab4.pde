import controlP5.*;
import processing.serial.*;
import java.util.HashMap;
import java.time.*;
import java.lang.Math.*;

ControlP5 cp5;
Clock time;
Serial myPort;
controlP5.Textarea serialTxt;
controlP5.Textarea  light, buzzer;
CheckBox checkbox;

int frameNumber = 0;
float maxLastTen = -1;
LocalTime alarmTime;
BufferedReader reader;
boolean use_file = true, val_changed = true;

float inByte = 0;
Chart sleepChart, liveChart ;
String textValue = "";
HashMap<String, Integer> colors;
int hours, min;

boolean rem = false, afterRem = false, alarmSet = false;
int endBlockHour;
int endBlockMin;
LocalTime blockTime;
long time2 = 0;


void setup() {
  reader = createReader("sleep_data.txt");
  if (use_file) {
    try {
      use_file = reader.ready();
      println("Using file");
    } catch (Exception e) {
      println("Error using file");
      e.printStackTrace();
      use_file = false;
    }
  }
  
  if (!use_file) {
    println("Trying to use serial port");
    try {
    myPort = new Serial(this, Serial.list()[0], 9600);
    myPort.bufferUntil('\n');
    } catch (Exception e) {
      serialTxt.setText("NO SERIAL");
    }
   }
  frameRate(1000);
  
  cp5 = new ControlP5(this);
  time = Clock.systemUTC();
  colors = new HashMap<String, Integer>();
  colors.put("red", #FF0000);
  colors.put("orange", #FFA500);
  colors.put("green", #00FF00);
  colors.put("blue", #00BFFF);
  colors.put("grey", #F0F8FF);
  colors.put("pink", #FFB6C1);
  colors.put("white", #FFFFFF);
  
  
  PFont pfont = createFont("arial",30);
  ControlFont font = new ControlFont(pfont,18);

  sleepChart = cp5.addChart("sleep chart")
               .setPosition(20, 15)
               .setSize(900, 575)
               .setRange(1023-900, 900)
               .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
               .setStrokeWeight(2.5)
               ;
  liveChart = cp5.addChart("live chart")
               .setPosition(950, 350)
               .setSize(200, 200)
               .setRange(1023-900, 900)
               .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
               .setStrokeWeight(2.5)
               ;

  sleepChart.addDataSet("sleep");
  sleepChart.setData("sleep", new float[3240]);
  sleepChart.setColors("sleep",#FFFFFF);
  sleepChart.getColor().setBackground(#000000);
  liveChart.addDataSet("sleep");
  liveChart.setData("sleep", new float[600]);
  size(1200,615);
  background(0x444444);
 
  /***************************************************************************************************/
  /***************************************************************************************************/
  /***************************************************************************************************/

  cp5.addTextfield("Time")
    .setPosition(950, 40)
    .setSize(150,30)
    .setAutoClear(false)
    .setFont(font)
    .getCaptionLabel()
    .setFont(font)
    ;
  checkbox = cp5.addCheckBox("checkBox")
                .setPosition(950, 150)
                .setSize(40, 40)
                .setItemsPerRow(1)
                .setSpacingColumn(30)
                .setSpacingRow(20)
                .addItem("buzz", 0)
                .addItem("light", 50)
                ;
                
                
                



  /***************************************************************************************************/
  /***************************************************************************************************/
  /***************************************************************************************************/
   
  
}


void draw() {
  background(0x444444);
  if (use_file) {
    readFromFile();
  }
  
  if (inByte > maxLastTen) {
    maxLastTen = inByte;
  }
  
  if (frameNumber % 100 == 0) {
    sleepChart.push("sleep", maxLastTen);
    maxLastTen = -1;
  }
  liveChart.push("sleep", inByte);
  frameNumber++;
  
  if (inByte == 1023 && alarmSet){
    rem = true;
    
  }
  
  if (rem && inByte != 1023){
    rem = false;
    afterRem = true;
    time2 = time.millis();
  }
  ;
  if(afterRem && (time.millis() - time2 > 60) ){
    sendAlarmTrigger();
  
  }
  
}


void readFromFile() {
  try {
    String line = reader.readLine();
    String sleepString = line;
    inByte = float(sleepString);
    if (!Float.isNaN(inByte))
      val_changed = true;
  } catch (Exception e) {
    e.printStackTrace();
    reader = createReader("sleep_data.txt");
    val_changed = false;
  }
}

   /***************************************************************************************************/
  /***************************************************************************************************/
  /***************************************************************************************************/

void serialEvent (Serial myPort) {
  // get the ASCII string:
  // get the ASCII string:
  String inString = myPort.readStringUntil('\n');
  println("Received serial data: "+inString);
  if (inString != null) {
    // trim off any whitespace:
    
    inString = trim(inString);

    // If leads off detection is true notify with blue line
    if (inString.equals("!")) { 
      stroke(0, 0, 0xff); //Set stroke to blue ( R, G, B)
      inByte = 512;  // middle of the ADC range (Flat Line)
    }
    // If the data is good let it through
    else {
      stroke(0xff, 0, 0); //Set stroke to red ( R, G, B)
      inByte = float(inString); 
     }
     //Map and draw the line for new data point
     inByte = map(inByte, 0, 1023, 0, height);
     // at the edge of the screen, go back to the beginning:
     val_changed = true;   
  }
}


// EVENT HANDLERS

 /***************************************************************************************************/
  /*******************EVENT HANDLERS********************************************************************************/
  /***************************************************************************************************/



public void controlEvent(ControlEvent theEvent) {

}


public void Time(String theText) {
  // automatically receives results from controller input
  println("a textfield event for controller 'Time' : "+theText);
  String array[] = theText.split(":");
  hours = int(array[0]);
  String minString = array[1];
  String amPm = minString.substring(2);
  minString = minString.substring(0, 2);
  min = int(array[1]);
  
  blockTime();

  alarmTime = LocalTime.parse(theText);
}

public void blockTime(){
  
 endBlockHour = hours - 2;
 blockTime = LocalTime.of(endBlockHour, min);
   alarmSet = true;

 
 
}

public void sendAlarmTrigger(){
  int h = hour();
  int m = minute();
  LocalTime time = LocalTime.of(h,m);
  
  if(alarmTime.compareTo(time)> 0 && blockTime.compareTo(time)< 0){
    
    myPort.write(0);
    
  } 

}