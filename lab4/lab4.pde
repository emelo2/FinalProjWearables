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
controlP5.Textlabel REMStatus; 

int numLs = 0;
int numBs = 0;
int frameNumber = 0;
float maxLastTen = -1;
LocalTime alarmTime;
BufferedReader reader;
boolean use_file = true, val_changed = true;

int speedUp = 1;
float inByte = 0;
Chart sleepChart, liveChart ;
String textValue = "";
HashMap<String, Integer> colors;
int hours, min;

boolean rem = false, isAfterRem = false, alarmSet = true, sendLightTrigger = false, sendBuzzerTrigger = false, buzzerCheckbox = false, lightCheckbox = false;
int endBlockHour;
int endBlockMin;
LocalTime detectionStartTime;
long endOfRemTime = 0;

void setup () {
  reader = createReader("RealFakeData.txt");
  if ( use_file ) {
    try {
      use_file = reader.ready();
      myPort = new Serial(this, Serial.list()[0], 9600);
      println("Using file");
    } catch (Exception e) {
      println("Error using file");
      e.printStackTrace();
      use_file = false;
    }
  }
  
  if ( !use_file ) {
    println("Trying to use serial port");
    try {
    myPort = new Serial(this, Serial.list()[0], 9600);
    myPort.bufferUntil('\n');
    } catch (Exception e) {
    }
   }
  frameRate(speedUp*5);
  
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
               .setRange(0, 1450)
               .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
               .setStrokeWeight(2.5)
               ;
  liveChart = cp5.addChart("live chart")
               .setPosition(950, 350)
               .setSize(200, 200)
               .setRange(0, 1450)
               .setView(Chart.LINE) // use Chart.LINE, Chart.PIE, Chart.AREA, Chart.BAR_CENTERED
               .setStrokeWeight(2.5)
               ;

  sleepChart.addDataSet("sleep");
  sleepChart.setData("sleep", new float[3240]);
  sleepChart.setColors("sleep",#FFFFFF);
  sleepChart.getColor().setBackground(#000000);
  liveChart.addDataSet("sleep");
  liveChart.setData("sleep", new float[150]);
  size(1200,615);
  background(0x444444);
 
  /***************************************************************************************************/
  /***************************************************************************************************/
  /***************************************************************************************************/
  int h = hour();
  int m = minute() + 30;
  if (m > 59) {
    m -= 60;
    h++;
  }
  String minuteString = Integer.toString(m);
  if (m < 10) {
    minuteString = "0"+m;
  }
  cp5.addTextfield("Time")
    .setPosition(950, 40)
    .setSize(150,30)
    .setAutoClear(false)
    .setText(h+":"+minuteString)
    .setFont(font)
    .getCaptionLabel()
    .setFont(font)
    ;
  checkbox = 
    cp5.addCheckBox("checkBox")
      .setPosition(950, 150)
      .setSize(40, 40)
      .setItemsPerRow(1)
      .setSpacingColumn(30)
      .setSpacingRow(20)
      .addItem("buzz", 0)
      .addItem("light", 50)
      ;
      
 REMStatus =      cp5.addTextlabel("REM")
      .setPosition(50, 50)
      .setFont(font)
      .setValue("Current Status");
}

void draw () {
  background(0x444444);
  
  REMStatus.setText("Deep Sleep");

  if (use_file && !sendBuzzerTrigger) {
    readFromFile();
  }

  if (inByte > maxLastTen) {
    maxLastTen = inByte;
  }

  if (frameNumber % 1 == 0) {
    sleepChart.push("sleep", maxLastTen);
    maxLastTen = -1;
  }

  liveChart.push("sleep", inByte);
  frameNumber++;

  if (inByte > 600 && alarmSet){
    sendLightTrigger = true;
    rem = true;
    isAfterRem = false;
    println("eye movement detected");
    REMStatus.setText("REM Cycle");
  }

  if (rem && inByte <= 600) {
    rem = false;
    isAfterRem = true;
    endOfRemTime = frameNumber;
    println("rem may have ended");
  }

  if (isAfterRem && (frameNumber - endOfRemTime >= 50)) {
    //println(frameNumber - endOfRemTime);
    println("rem cycle ended");
    REMStatus.setText("REM Cycle Ended, WAKE UP!");
    sendBuzzerTrigger = true;
  }

  if (sendLightTrigger && lightCheckbox) {
    if (numLs < 10)
      sendLightTrigger();
    numLs++;
  }
  if( sendBuzzerTrigger && buzzerCheckbox ){
    if (numBs < 10)
      sendBuzzerTrigger();
    numBs++;
  }
}

void readFromFile () {
  try {
    String line = reader.readLine();
    String sleepString = line;
    inByte = float(sleepString);
    if (!Float.isNaN(inByte))
      val_changed = true;
  } catch (Exception e) {
    //e.printStackTrace();
    reader = createReader("RealFakeData.txt");
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
  //println("Received serial data: "+inString);
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



public void controlEvent (ControlEvent theEvent) {

    if(theEvent.isFrom(checkbox)){
      
      for(int i = 0; i < checkbox.getArrayValue().length ; i++){ 
        
      int n = (int)checkbox.getArrayValue()[i];
      if(n == 1){
        if(checkbox.getItem(i).getName() == "buzz"){
          buzzerCheckbox = true;
        }
        else{
          lightCheckbox = true;
        }
      }
      
    }
}
}

public void Time (String theText) {
  // automatically receives results from controller input
  println("a textfield event for controller 'Time' : "+theText);
  String array[] = theText.split(":");
  hours = int(array[0]);
  String minString = array[1];
  String amPm = minString.substring(2);
  minString = minString.substring(0, 2);
  min = int(array[1]);

  setAlarm();
  alarmTime = LocalTime.of(hours, min);
}

public void setAlarm () {
  endBlockHour = hours - 2;
  detectionStartTime = LocalTime.of(endBlockHour, min);
  println("Alarm is set");
  print("Detection start time is ");
  println(detectionStartTime);
  alarmSet = true;
}

public void sendLightTrigger () {
  if (lightCheckbox) {
    println("Writing 'l' to arduino");
    myPort.write('l');
  }
}

public void sendBuzzerTrigger () {
  if (buzzerCheckbox) {
    println("Writing 'b' to arduino");
    myPort.write('b');
  }
}