import ddf.minim.*;
import ddf.minim.signals.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.spi.*;
import ddf.minim.ugens.*;

Minim m;


AudioPlayer song;

AudioBuffer buffer;
AudioInput ai;
FFT fft;

//---------------------------------------------------------------//---------------------------------------------------------------
// For when which == 1
// Variables which define the "zones" of the spectrum

float specLow = 0.03; // 3%
float specMid = 0.125;  // 12.5%
float specHi = 0.20;   // 20%

// Score values for each zone
float scoreLow = 0;
float scoreMid = 0;
float scoreHi = 0;

// Previous value, to soften the reduction
float oldScoreLow = scoreLow;
float oldScoreMid = scoreMid;
float oldScoreHi = scoreHi;

// Softening value   default 25
float scoreDecreaseRate = 25;

// Cubes that appear in space
int nbCubes;
Cube[] cubes;

//---------------------------------------------------------------//---------------------------------------------------------------
// for when which == 2
float lerpedAverage = 0;

float[] lerpedBuffer;


int cols, rows;
int scl = 20;
int w = 1440;
int h = 2560;

float flying = 0;

float[][] terrain;

//---------------------------------------------------------------//---------------------------------------------------------------

void setup()
{
  fullScreen(P3D);

  // Make processing use minim
  m = new Minim(this);

  // Associate the song file to the value of song
  song = m.loadFile("Temptations.mp3", 1024);


  fft = new FFT(song.bufferSize(), song.sampleRate() );


  song.play(0);
  //---------------------------------------------------------------//---------------------------------------------------------------
  // For when which == 1
  nbCubes = (int)(fft.specSize()*specHi * 2 );
  cubes = new Cube[nbCubes];

  for (int i = 0; i < nbCubes; i++) 
  {
    cubes[i] = new Cube();
  }

  //---------------------------------------------------------------//---------------------------------------------------------------
  // For when which == 2
  cols = w / scl;
  rows = h/ scl;
  terrain = new float[cols][rows];
  buffer = song.left;

  lerpedBuffer = new float[buffer.size()];

  //---------------------------------------------------------------//---------------------------------------------------------------
}

int which = 1;

void draw()
{
  println(which);
  //---------------------------------------------------------------//---------------------------------------------------------------

  if ( which == 1 )
  {
    // Advance the song. We draw () for each "frame" of the song ...
    fft.forward(song.mix);

    // Calculation of the "scores" (power) for three categories of sound
    // First, save the old values
    oldScoreLow = scoreLow;
    oldScoreMid = scoreMid;
    oldScoreHi = scoreHi;

    // Reset the values
    scoreLow = 0;
    scoreMid = 0;
    scoreHi = 0;

    // Calculate the new "scores"
    for (int i = 0; i < fft.specSize()*specLow; i++)
    {
      scoreLow += fft.getBand(i);
    }

    for (int i = (int)(fft.specSize()*specLow); i < fft.specSize()*specMid; i++)
    {
      scoreMid += fft.getBand(i);
    }

    for (int i = (int)(fft.specSize()*specMid); i < fft.specSize()*specHi; i++)
    {
      scoreHi += fft.getBand(i);
    }

    // Slow down the descent.
    if (oldScoreLow > scoreLow) {
      scoreLow = oldScoreLow - scoreDecreaseRate;
    }

    if (oldScoreMid > scoreMid) {
      scoreMid = oldScoreMid - scoreDecreaseRate;
    }

    if (oldScoreHi > scoreHi) {
      scoreHi = oldScoreHi - scoreDecreaseRate;
    }

    // Volume for all frequencies at this time, with higher sounds more prominent.
    // This allows the animation to go faster for higher pitched sounds, which are more noticeable
    float scoreGlobal = 0.66*scoreLow + 0.8*scoreMid + 1*scoreHi;

    // Subtle background color  def /100 for all
    background(scoreLow/25, scoreMid/25, scoreHi/25);

    // Cube for each frequency band
    for (int i = 0; i < nbCubes; i++)
    {
      // Value of the frequency band
      float bandValue = fft.getBand(i);

      // The color is represented as: red for bass, green for mid sounds, and blue for highs.
      // The opacity is determined by the volume of the tape and the overall volume.
      // Def = no division
      cubes[i].display(scoreLow, scoreMid, scoreHi, bandValue / 1.2, scoreGlobal / 1.2);
    }
  }

  //---------------------------------------------------------------//---------------------------------------------------------------

  if ( which == 2 )
  {
    float sum = 0;
    for (int i = 0; i < buffer.size(); i ++)
    {
      sum += abs(buffer.get(i));
    }

    noStroke();
    float average = sum / buffer.size();
    lerpedAverage = lerp(lerpedAverage, average, 0.1f);


    flying -=lerpedAverage/5;

    float yoff = flying;
    for (int y = 0; y < rows; y++) {
      float xoff = 0;
      for (int x = 0; x < cols; x++) {
        terrain[x][y] = map(noise(xoff, yoff), 0, 1, -lerpedAverage*300, lerpedAverage*300);
        xoff += 0.2;
      }
      yoff += 0.2;
    }

    //background(#040B46);
    background(5);

    // Sphere on top
    pushMatrix();
    fill(#0C05FF, lerpedAverage*1000);
    stroke(#1FEAFF, 255);
    translate(width/2, height/8);
    sphere(lerpedAverage*300);
    popMatrix();


    // Retro wave
    pushMatrix();
    //fill(#471FFF);
    // 0.67
    color Wave = color(scoreLow*0.33, scoreMid*0.33, scoreHi*0.33, 75);
    fill(Wave, 255);
    stroke(#1FEAFF);  
    translate(width/2, height/2+50);
    rotateX(PI/3);
    translate(-w/2, -h/2);
    for (int y = 0; y < rows-1; y++) {
      beginShape(TRIANGLE_STRIP);
      for (int x = 0; x < cols; x++) {
        vertex(x*scl, y*scl, terrain[x][y]);
        vertex(x*scl, (y+1)*scl, terrain[x][y+1]);

        //rect(x*scl, y*scl, scl, scl);
      }
      endShape();
    }

    popMatrix();
  }
}

//---------------------------------------------------------------//---------------------------------------------------------------



// Class for the cubes which float in space
class Cube {
  // Z position of "spawn" and maximum Z position
  float startingZ = -10000;
  float maxZ = 1000;

  // Position values
  float x, y, z;
  float rotX, rotY, rotZ;
  float sumRotX, sumRotY, sumRotZ;

  // Cube Constructor
  Cube() {
    // Make the cube appear at a random location
    x = random(0, width);
    y = random(0, height);
    z = random(startingZ, maxZ);

    // Give the cube a random rotation
    rotX = random(0, 1);
    rotY = random(0, 1);
    rotZ = random(0, 1);
  }

  void display(float scoreLow, float scoreMid, float scoreHi, float intensity, float scoreGlobal) 
  {
    // Select the color, opacity determined by the intensity (volume of the band) int = 5
    color displayColor = color(scoreLow*0.67, scoreMid*0.67, scoreHi*0.67, intensity*5);
    fill(displayColor, 255);

    // Line color, they disappear with the individual intensity of the cube
    color strokeColor = color(255, 150-(20*intensity));
    stroke(strokeColor);
    strokeWeight(1 + (scoreGlobal/400));  //scoreG/300

    // Create a transformation matrix to perform rotations, enlargements
    pushMatrix();

    //Shifting
    translate(x, y, z);

    // Calculate the rotation according to the intensity for the cube Def = 1000
    sumRotX += intensity*(rotX/2000);
    sumRotY += intensity*(rotY/2000);
    sumRotZ += intensity*(rotZ/2000);

    // Apply the rotation
    rotateX(sumRotX);
    rotateY(sumRotY);
    rotateZ(sumRotZ);

    // Creation of the box, variable size according to the intensity for the cube Def = 2
    box(100 +(intensity/2));

    // Apply the matrix
    popMatrix();

    // Z displacement  Def int = /5 scoreG = /150
    z+= (1+(intensity/7)+(pow((scoreGlobal/225), 2)));

    // Replace the box at the back when it is no longer visible
    if (z >= maxZ) {
      x = random(0, width);
      y = random(0, height);
      z = startingZ;
    }
  }
}


// Play / Pause the song.
void keyPressed()
{
  // Set the value of which based on which key was pressed
  if (keyCode >= '1' && keyCode <= '2')
  {
    which = keyCode - '0';
  }
  if (keyCode == ' ')
  {
    if ( song.isPlaying() )
    {
      song.pause();
    } else
    {
      song.play();
    }
  }
}
