import 'package:flutter/material.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // this is the body and it makes it scrollable
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Container(
              padding: EdgeInsets.only(top: 30.0, left: 20.2, right: 20.0),
              width: MediaQuery.of (context).size.width,
              decoration: BoxDecoration(
                  gradient:  LinearGradient(colors: [
                    Color(0xff326178),
                    Color(0xffdff1fc),],
                      begin: Alignment.topRight, end: Alignment.bottomLeft)),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Hello User",
                  style: TextStyle(color: Colors.orange,fontSize:22,fontWeight: FontWeight.bold),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                    child: Image.asset("lib/Assets/images/User.png",
                      height:50,
                      width:50,
                      fit: BoxFit.cover,))
              ],
            ),
              // this is head section and al;so its head
              Text("Which service do\nyou need?",
                style: TextStyle(
                    color: Color(0xff284a79),
                    fontSize:25,
                    fontWeight: FontWeight.bold),
              ),
              // this is the search bar
              SizedBox(height: 20.0,),
              Container(
                padding:EdgeInsets.only(left: 20.0),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(10)),
              child: TextField(
                decoration: InputDecoration(
                    border: InputBorder.none, hintText: "How can I help you??",
                    hintStyle: TextStyle(color: Colors.black45),
                    suffixIcon: Icon(Icons.search, color: Color(0xff284a79),)),
              ),
              ),
              // this is the service categories
              SizedBox(height:20.0),
              Row(children: [
                Column(
                  children: [
                    Container(
                      padding:EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60)),
                      child: Image.asset("lib/Assets/images/carpenter.png",
                        height: 30,
                        width: 30,
                      fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 5.0,),
                    Text(
                      "Carpenter",
                      style: TextStyle(
                          color: Color(0xff284a79),
                          fontSize:16.0,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
                SizedBox(width: 20.0,),
                Column(
                  children: [
                    Container(
                      padding:EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60)),
                      child: Image.asset("lib/Assets/images/cleaner.png",
                        height: 30,
                        width: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 5.0,),
                    Text(
                      "Cleaner",
                      style: TextStyle(
                          color: Color(0xff284a79),
                          fontSize:16.0,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
                SizedBox(width: 20.0,),
                Column(
                  children: [
                    Container(
                      padding:EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60)),
                      child: Image.asset("lib/Assets/images/electrician.png",
                        height: 30,
                        width: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 5.0,),
                    Text(
                      "Electrician",
                      style: TextStyle(
                          color: Color(0xff284a79),
                          fontSize:16.0,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
                SizedBox(width: 20.0,),
                Column(
                  children: [
                    Container(
                      padding:EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60)),
                      child: Image.asset("lib/Assets/images/plumber.png",
                        height: 30,
                        width: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(height: 5.0,),
                    Text(
                      "Plumber",
                      style: TextStyle(
                          color: Color(0xff284a79),
                          fontSize:16.0,
                          fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ],
              ),
               SizedBox(
                 height: 25.0,
               ),
             ],
          ),
        ),
        // this is the popular service section
        Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 10.0),
          child: Text(
            "Populate services",
            style: TextStyle(
                color: Color(0xff284a79),
                fontSize:22.0,
                fontWeight: FontWeight.bold),
          ),
        ),
            Container(
              padding: EdgeInsets.only(left: 20, top: 20, bottom: 20),
              margin: EdgeInsets.only(left: 20,right: 20),
              width: MediaQuery.of (context).size.width,
              decoration: BoxDecoration(color:Color(0xffdff1fc), borderRadius: BorderRadius.circular(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset("lib/Assets/images/User.png",
                      height: 70,
                      width: 70,
                      fit: BoxFit.cover,
                    ),
                ),
                SizedBox(width: 10.0,),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(children: [
                    Icon(Icons.star,
                      color: Colors.yellow,
                    ),
                    Text(
                      "4.5",
                      style: TextStyle(
                          color: Color(0xff284a79),
                          fontSize:18.0,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                  ),
                  SizedBox(height: 5,),
                  Text(
                    "Home Cleaning ",
                    style: TextStyle(
                        color: Color(0xff284a79),
                        fontSize:18.0,
                        fontWeight: FontWeight.bold),
                  ),
                    Text(
                      "By: Random user134 ",
                      style: TextStyle(
                          color: Color(0xff284a79),
                          fontSize:13.0,
                          fontWeight: FontWeight.w400),
                    ),
                    SizedBox(height:5),
                    Row(children: [
                        Container(
                          padding: EdgeInsets.all(5),
                          width: 100,
                          decoration: BoxDecoration(color:  Color(0xff326178),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: Center(
                            child: Text(
                              "Rs 500/Hour",
                               style: TextStyle(
                                color: Colors.white,
                                fontSize:15.0,
                                fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                     SizedBox(width: 20,),
                      Container(
                        padding: EdgeInsets.all(5),
                        width: 90,
                        decoration: BoxDecoration(color:  Color(0xff359bd8),
                            borderRadius: BorderRadius.circular(10)
                        ),
                        child: Center(
                          child: Text(
                            "Find Now",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize:15.0,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    ],
                    ),
                ],
                )

              ],
              ),
            ),
            SizedBox(height: 10,),
            Container(
              padding: EdgeInsets.only(left: 20, top: 20, bottom: 20),
              margin: EdgeInsets.only(left: 20,right: 20),
              width: MediaQuery.of (context).size.width,
              decoration: BoxDecoration(color:Color(0xffdff1fc), borderRadius: BorderRadius.circular(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset("lib/Assets/images/User.png",
                      height: 70,
                      width: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: 10.0,),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.star,
                          color: Colors.yellow,
                        ),
                        Text(
                          "4.5",
                          style: TextStyle(
                              color: Color(0xff284a79),
                              fontSize:18.0,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                      ),
                      SizedBox(height: 5,),
                      Text(
                        "Plumber",
                        style: TextStyle(
                            color: Color(0xff284a79),
                            fontSize:18.0,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "By: Random user124 ",
                        style: TextStyle(
                            color: Color(0xff284a79),
                            fontSize:13.0,
                            fontWeight: FontWeight.w400),
                      ),
                      SizedBox(height:5),
                      Row(children: [
                        Container(
                          padding: EdgeInsets.all(5),
                          width: 100,
                          decoration: BoxDecoration(color:  Color(0xff326178),
                              borderRadius: BorderRadius.circular(10)
                          ),
                          child: Center(
                            child: Text(
                              "Rs 350/Hour",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize:15.0,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        SizedBox(width: 20,),
                        Container(
                          padding: EdgeInsets.all(5),
                          width: 100,
                          decoration: BoxDecoration(color:  Color(0xff359bd8),
                              borderRadius: BorderRadius.circular(10)
                          ),
                          child: Center(
                            child: Text(
                              "Find Now",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize:15.0,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      ],
                      ),
                    ],
                  )

                ],
              ),
            ),
            SizedBox(height: 10,),
            Container(
              padding: EdgeInsets.only(left: 20, top: 20, bottom: 20),
              margin: EdgeInsets.only(left: 20,right: 20),
              width: MediaQuery.of (context).size.width,
              decoration: BoxDecoration(color:Color(0xffdff1fc), borderRadius: BorderRadius.circular(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset("lib/Assets/images/User.png",
                      height: 70,
                      width: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: 10.0,),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.star,
                          color: Colors.yellow,
                        ),
                        Text(
                          "3.5",
                          style: TextStyle(
                              color: Color(0xff284a79),
                              fontSize:18.0,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                      ),
                      SizedBox(height: 5,),
                      Text(
                        "Carpenter",
                        style: TextStyle(
                            color: Color(0xff284a79),
                            fontSize:18.0,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "By: Random user123 ",
                        style: TextStyle(
                            color: Color(0xff284a79),
                            fontSize:13.0,
                            fontWeight: FontWeight.w400),
                      ),
                      SizedBox(height:5),
                      Row(children: [
                        Container(
                          padding: EdgeInsets.all(5),
                          width: 100,
                          decoration: BoxDecoration(color:  Color(0xff326178),
                              borderRadius: BorderRadius.circular(10)
                          ),
                          child: Center(
                            child: Text(
                              "Rs 250/Hour",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize:15.0,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        SizedBox(width: 20,),
                        Container(
                          padding: EdgeInsets.all(5),
                          width: 100,
                          decoration: BoxDecoration(color:  Color(0xff359bd8),
                              borderRadius: BorderRadius.circular(10)
                          ),
                          child: Center(
                            child: Text(
                              "Find Now",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize:15.0,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      ],
                      ),
                    ],
                  )

                ],
              ),
            ),
      ],
      ),
      ),
    );
  }
}
